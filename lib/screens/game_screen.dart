import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart' show GameWidget;
import 'package:http/http.dart' as http;

import '../game/fighter_game.dart';
import '../game/ai/ai_controller.dart';
import '../game/network/rollback_engine.dart';
import '../game/components/fighter.dart';
import '../network/network_manager.dart';
import '../network/game_client.dart';
import '../data/device_id.dart';
import '../data/nickname.dart';
import '../i18n/app_localizations.dart';

/// Flutter screen that hosts the Flame [FighterGame] instance.
class GameScreen extends StatefulWidget {
  final String hero1Id;
  final String hero2Id;
  final String mode;
  final NetworkManager? network; // For online/lan network sync
  final int mySlot; // Which player slot this device controls (0 or 1)
  final int rollbackSeed; // Server-provided seed for deterministic PRNG sync

  const GameScreen({
    super.key,
    required this.hero1Id,
    required this.hero2Id,
    required this.mode,
    this.network,
    this.mySlot = 0,
    this.rollbackSeed = 0,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FocusNode _focusNode = FocusNode();
  late final FighterGame _game;
  Timer? _inputSendTimer;
  StreamSubscription? _inputSub;
  StreamSubscription? _gameEndSub;
  StreamSubscription? _disconnectSub;
  StreamSubscription? _errorSub;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();

    // Hide system UI for immersive full-screen gameplay
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ));
    // Set preferred orientations to landscape only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _game = FighterGame(
      hero1Id: widget.hero1Id,
      hero2Id: widget.hero2Id,
      mode: widget.mode,
    );

    // Apply rollback seed from server (deterministic PRNG sync)
    if (widget.rollbackSeed != 0) {
      _game.applyRollbackSeed(widget.rollbackSeed);
      _game.predictionFrames = 30; // 1 second of prediction at 30fps
    }

    // Set local player index for network mode
    if (widget.mode == 'online' || widget.mode == 'lan') {
      _game.localPlayerIndex = widget.mySlot;
    }

    // Set up AI controller for player 2 in AI mode
    if (widget.mode == 'ai') {
      _game.onExternalUpdate = _onAiTick;
    }

    // Set up network sync for online/lan mode
    if ((widget.mode == 'online' || widget.mode == 'lan') && widget.network != null) {
      _setupNetworkSync();
    }

    // Listen for game state changes to save records (AI/local mode)
    _game.onGameStateChanged = _onGameStateChanged;
  }

  void _onGameStateChanged(GameState newState) {
    if (newState == GameState.result) {
      // Game ended, save record for AI/local mode
      _saveGameRecord();
    }
  }

  void _setupNetworkSync() {
    final net = widget.network!;

    // Create rollback engine and hook into FighterGame
    final engine = RollbackEngine(game: _game);
    _game.rollbackEngine = engine;

    // Listen for opponent's inputs from server — feed into rollback engine
    _inputSub = net.onGameInputStream.listen((data) {
      final inputs = data['inputs'] as Map<String, dynamic>?;
      if (inputs == null) return;
      final frame = data['frame'] as int? ?? 0;
      final remoteInput = FighterInput()
        ..left = inputs['left'] == true
        ..right = inputs['right'] == true
        ..up = inputs['up'] == true
        ..down = inputs['down'] == true
        ..jump = inputs['jump'] == true
        ..attack = inputs['attack'] == true
        ..skill = inputs['skill'] == true;
      _game.receiveRemoteInput(frame, remoteInput);
    });

    // Listen for game end
    _gameEndSub = net.onGameEndStream.listen((data) {
      if (!mounted) return;
      final reason = data['reason'] as String? ?? 'game_over';
      final l10n = AppLocalizations.fromSystemLocale();
      // winnerId available in data['winnerId'] if needed
      if (reason == 'opponent_disconnected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.opponentDisconnected), backgroundColor: Colors.redAccent),
        );
      }
    });

    // Listen for disconnect
    _disconnectSub = net.onDisconnectedStream.listen((reason) {
      if (!mounted) return;
      final l10n = AppLocalizations.fromSystemLocale();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.networkDisconnected}: $reason'), backgroundColor: Colors.redAccent),
      );
    });

    _errorSub = net.onErrorStream.listen((msg) {
      if (!mounted) return;
      final l10n = AppLocalizations.fromSystemLocale();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.networkError}: $msg'), backgroundColor: Colors.redAccent),
      );
    });

    // Start sending local input periodically (~30fps, with frame number for rollback sync)
    _inputSendTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted || !net.isConnected) {
        timer.cancel();
        return;
      }
      final engine = _game.rollbackEngine;
      final localInput = engine?.lastLocalInput() ?? _game.getLocalInput(widget.mySlot);
      final frame = engine?.currentFrame ?? _frame;
      net.sendInput(frame, localInput);
      _frame++;
    });
  }

  void _onAiTick(double dt) {
    // Lazily create AI controller once fighters are available
    if (_game.player2.heroId.isEmpty) return;
    // Remove self after first setup
    _game.onExternalUpdate = AiController(
      fighter: _game.player2,
      difficulty: AiDifficulty.medium,
      rng: _game.gameRandom,
    ).update;
  }

  @override
  void dispose() {
    _inputSendTimer?.cancel();
    _inputSub?.cancel();
    _gameEndSub?.cancel();
    _disconnectSub?.cancel();
    _errorSub?.cancel();
    _focusNode.dispose();
    _game.onRemove();
    widget.network?.disconnect();
    widget.network?.dispose();
    // Restore system UI and default orientations
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  void _exitToMenu() {
    // Send game end to opponent if in network mode
    if (widget.network != null && (widget.mode == 'online' || widget.mode == 'lan')) {
      widget.network!.sendGameEnd(reason: 'player_left');
    }
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  void _restartGame() {
    _game.resetRound();
    _focusNode.requestFocus();
  }

  /// 保存游戏记录到服务器（AI/本地模式）
  Future<void> _saveGameRecord() async {
    // 只在 AI 或本地 2P 模式保存
    if (widget.mode != 'ai' && widget.mode != 'local') return;
    
    final winnerName = _game.winnerName;
    if (winnerName == null) return;
    
    try {
      final deviceId = await getDeviceId();
      final nickname = await getNickname() ?? 'Player';
      
      // 确定胜负
      String? winnerId;
      String player1Id = deviceId;
      String player2Id = widget.mode == 'local' ? 'local_p2_$deviceId' : 'ai_$deviceId';
      String player1Name = nickname;
      String player2Name = widget.mode == 'local' ? 'Player 2' : 'AI';
      
      if (winnerName.contains(nickname) || winnerName.contains('Player 1')) {
        winnerId = player1Id;
      } else if (!winnerName.contains('Draw')) {
        winnerId = player2Id;
      }
      
      // 发送游戏记录到服务器（使用 HTTP POST）
      final url = Uri.parse('${AppConfig.apiBaseUrl}/api/game_record');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'player1Id': player1Id,
          'player2Id': player2Id,
          'player1Hero': widget.hero1Id,
          'player2Hero': widget.hero2Id,
          'winnerId': winnerId,
          'player1Name': player1Name,
          'player2Name': player2Name,
          'gameMode': widget.mode,
        }),
      );
      
      if (response.statusCode == 200) {
        print('Game record saved: $winnerName');
      } else {
        print('Failed to save game record: ${response.body}');
      }
    } catch (e) {
      print('Failed to save game record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.fromSystemLocale();
    final isNetworkMode = widget.mode == 'online' || widget.mode == 'lan';

    final safeLeft = MediaQuery.of(context).padding.left;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final safeRight = MediaQuery.of(context).padding.right;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _exitToMenu();
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Game widget fills entire screen including safe areas
            Positioned.fill(child: GameWidget(game: _game)),
            // Top bar controls — offset by safe area to avoid Dynamic Island in landscape
            Positioned(
              top: safeTop + 4, left: safeLeft + 4, right: safeRight + 4,
              child: Row(children: [
                _SmallButton(icon: Icons.arrow_back, onTap: _exitToMenu, label: l10n.exit),
                const SizedBox(width: 4),
                _SmallButton(icon: Icons.refresh, onTap: _restartGame, label: l10n.restart),
                // Network status indicator
                if (isNetworkMode && widget.network != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _BuildNetworkStatus(network: widget.network!),
                  ),
              ]),
            ),
            // Controls hint — offset by safe area to avoid home indicator
            if (widget.mode == 'ai')
              Positioned(
                bottom: safeBottom + 4, left: safeLeft + 4, right: safeRight + 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: Text(l10n.controlsAi, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ),
              )
            else if (widget.mode == 'local')
              Positioned(
                bottom: safeBottom + 4, left: safeLeft + 4, right: safeRight + 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: Text(l10n.controlsLocal, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ),
              )
            else if (isNetworkMode)
              Positioned(
                bottom: safeBottom + 4, left: safeLeft + 4, right: safeRight + 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    widget.mySlot == 0 ? l10n.controlsNetworkP1 : l10n.controlsNetworkP2,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Network status widget showing connection and ping
class _BuildNetworkStatus extends StatefulWidget {
  final NetworkManager network;
  const _BuildNetworkStatus({required this.network});

  @override
  State<_BuildNetworkStatus> createState() => _BuildNetworkStatusState();
}

class _BuildNetworkStatusState extends State<_BuildNetworkStatus> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.fromSystemLocale();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.network.isConnected
            ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: widget.network.isConnected ? const Color(0xFF4CAF50) : Colors.redAccent,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: widget.network.isConnected ? const Color(0xFF4CAF50) : Colors.redAccent,
          ),
          const SizedBox(width: 4),
          Text(
            widget.network.isConnected ? l10n.connected : l10n.disconnected,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  const _SmallButton({required this.icon, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
