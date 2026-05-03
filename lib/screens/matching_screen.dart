import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../network/network_manager.dart' as net;
import '../i18n/app_localizations.dart';
import 'hero_select.dart';

/// Matchmaking screen that handles:
/// 1. Auto-discovering LAN server (UDP broadcast)
/// 2. Connecting via WebSocket
/// 3. Entering matchmaking queue
/// 4. Displaying matching status
/// 5. Navigating to synced hero selection on match found
class MatchingScreen extends StatefulWidget {
  final String mode; // 'online' or 'lan'
  final String? serverAddress; // optional explicit server address

  const MatchingScreen({
    super.key,
    this.mode = 'lan',
    this.serverAddress,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

enum _MatchState {
  discovering,   // Discovering LAN servers
  connecting,    // Connecting to server
  queued,        // In matchmaking queue
  matched,       // Match found!
  error,         // Error occurred
}

class _MatchingScreenState extends State<MatchingScreen>
    with TickerProviderStateMixin {
  final net.NetworkManager _network = net.NetworkManager();

  late AnimationController _pulseController;
  late AnimationController _spinController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnim;
  late Animation<double> _glowAnim;

  _MatchState _matchState = _MatchState.discovering;
  String _statusText = '';
  String? _errorMessage;
  String? _opponentName;
  int _dots = 0;
  Timer? _dotsTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _setupNetworkCallbacks();
    _startDiscovery();
  }

  void _setupNetworkCallbacks() {
    final l10n = AppLocalizations.fromSystemLocale();
    _network.onConnectionStateChanged = (state) {
      if (!mounted) return;
      switch (state) {
        case net.ConnectionState.connecting:
          setState(() {
            _matchState = _MatchState.connecting;
            _statusText = l10n.connectingToServer;
          });
          break;
        case net.ConnectionState.connected:
          _enterMatchmaking();
          break;
        case net.ConnectionState.disconnected:
          if (_matchState != _MatchState.matched) {
            setState(() {
              _matchState = _MatchState.error;
              _errorMessage = l10n.connectionLost;
              _statusText = l10n.connectionDisconnected;
            });
          }
          break;
        case net.ConnectionState.error:
          if (_matchState != _MatchState.matched) {
            setState(() {
              _matchState = _MatchState.error;
              _errorMessage = l10n.connectionFailed;
              _statusText = l10n.connectionFailed;
            });
          }
          break;
        default:
          break;
      }
    };

    _network.onMatchmakingStatus = (status) {
      if (!mounted) return;
      if (status['status'] == 'queued') {
        setState(() {
          _matchState = _MatchState.queued;
          _statusText = l10n.waitingForOpponentJoin;
        });
        _startDotAnimation();
      } else if (status['status'] == 'cancelled') {
        setState(() {
          _statusText = l10n.matchingCancelled;
        });
      }
    };

    _network.onMatchFound = (data) {
      if (!mounted) return;
      _dotsTimer?.cancel();
      setState(() {
        _matchState = _MatchState.matched;
        _opponentName = data['opponentName'] as String? ?? l10n.opponent;
        _statusText = l10n.matchFound;
      });

      // Brief delay to show "matched!" then navigate
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        // Pass network manager directly (same connection, same room)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HeroSelectScreen(
              mode: widget.mode,
              network: _network,
              mySlot: _network.mySlot,
            ),
          ),
        );
      });
    };

    _network.onError = (msg) {
      if (!mounted || _matchState == _MatchState.matched) return;
      setState(() {
        _matchState = _MatchState.error;
        _errorMessage = msg;
        _statusText = l10n.errorOccurred;
      });
    };

    _network.onLanServerFound = (server) {
      if (_matchState != _MatchState.discovering) return;
      if (!mounted) return;
      setState(() {
        _matchState = _MatchState.connecting;
        _statusText = '${l10n.foundServer}${server.name}';
      });
      // Connect to the discovered server
      _network.connectToLanServer(server);
    };
  }

  Future<void> _startDiscovery() async {
    final l10n = AppLocalizations.fromSystemLocale();
    setState(() {
      _matchState = _MatchState.discovering;
      _statusText = l10n.searchingServers;
    });

    String wsUrl;
    if (widget.serverAddress != null) {
      // 如果传入了指定服务器地址，使用它
      wsUrl = 'wss://${widget.serverAddress}';
    } else {
      // 否则使用配置文件中的地址（同时适用于 Web 和 Native）
      wsUrl = AppConfig.wsUrl;
    }

    setState(() {
      _matchState = _MatchState.connecting;
      _statusText = '${l10n.connectingTo}$wsUrl ...';
    });
    try {
      await _network.connect(wsUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _matchState = _MatchState.error;
        _errorMessage = '${l10n.connectionFailedWithError}$e';
        _statusText = l10n.connectionFailed;
      });
    }

    // Timeout after 5 seconds if no server found
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_matchState == _MatchState.discovering) {
        setState(() {
          _matchState = _MatchState.error;
          _errorMessage = l10n.noLanServer;
          _statusText = l10n.noServerFound;
        });
      }
    });
  }

  void _enterMatchmaking() {
    final l10n = AppLocalizations.fromSystemLocale();
    setState(() {
      _matchState = _MatchState.queued;
      _statusText = l10n.enteringQueue;
    });
    _network.requestMatchmaking();
  }

  void _startDotAnimation() {
    _dotsTimer?.cancel();
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _dots = (_dots + 1) % 4);
    });
  }

  void _cancelMatchmaking() {
    _dotsTimer?.cancel();
    _network.cancelMatchmaking();
    _network.disconnect();
    Navigator.pop(context);
  }

  void _retry() {
    final l10n = AppLocalizations.fromSystemLocale();
    // Reset and try again
    setState(() {
      _matchState = _MatchState.discovering;
      _errorMessage = null;
      _statusText = l10n.retrySearch;
    });
    _startDiscovery();
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _pulseController.dispose();
    _spinController.dispose();
    _glowController.dispose();
    if (_matchState != _MatchState.matched) {
      // Only disconnect+dispose if we didn't match (network passed downstream)
      _network.cancelMatchmaking();
      _network.disconnect();
      _network.dispose();
    }
    // If matched, network ownership transfers to HeroSelectScreen → GameScreen
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.fromSystemLocale();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D2B), Color(0xFF1A0A3E), Color(0xFF2A1A1A)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background particles
              ...List.generate(8, (i) => _MatchingParticle(
                index: i,
                controller: _spinController,
              )),
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),

                        // Mode indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.mode == 'lan' ? Icons.wifi : Icons.public,
                                color: Colors.white54,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.mode == 'lan' ? l10n.lanMatch : l10n.onlineMatch,
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Animated search icon
                        _buildAnimatedIcon(),

                        const SizedBox(height: 40),

                        // Status text
                        Text(
                          _statusText + '.' * _dots,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Extra info based on state
                        _buildStateInfo(),

                        const SizedBox(height: 50),

                        // Action buttons
                        _buildActionButtons(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    switch (_matchState) {
      case _MatchState.matched:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF81C784), Color(0xFF4CAF50)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 50),
              ),
            );
          },
        );

      case _MatchState.error:
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.2),
            border: Border.all(color: Colors.redAccent, width: 2),
          ),
          child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
        );

      default:
        // Spinning radar/search animation
        return AnimatedBuilder(
          animation: _spinController,
          builder: (context, child) {
            return AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: _glowAnim.value * 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Middle ring (spinning)
                    Transform.rotate(
                      angle: _spinController.value * 2 * pi,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    // Inner ring (counter-rotate)
                    Transform.rotate(
                      angle: -_spinController.value * 3 * pi,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    // Center dot with glow
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFD700),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: _glowAnim.value),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
    }
  }

  Widget _buildStateInfo() {
    final l10n = AppLocalizations.fromSystemLocale();
    switch (_matchState) {
      case _MatchState.queued:
        return Column(
          children: [
            Text(
              l10n.inQueue,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            // Scanning line animation hint
            Text(
              l10n.lookingForOpponent,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        );

      case _MatchState.matched:
        return Column(
          children: [
            Text(
              _opponentName ?? l10n.opponentFound,
              style: const TextStyle(
                color: Color(0xFF81C784),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.enteringHeroSelection,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        );

      case _MatchState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _errorMessage ?? l10n.unknownError,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        );

      case _MatchState.discovering:
        return Text(
          l10n.ensureDeviceRunning,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.fromSystemLocale();
    if (_matchState == _MatchState.error) {
      return Column(
        children: [
          _ActionButton(
            label: l10n.retry,
            icon: Icons.refresh,
            color: Colors.orangeAccent,
            onTap: _retry,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: l10n.back,
            icon: Icons.arrow_back,
            color: Colors.white54,
            onTap: () => Navigator.pop(context),
          ),
        ],
      );
    }

    if (_matchState == _MatchState.matched) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: const LinearProgressIndicator(
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(Color(0xFF4CAF50)),
        ),
      );
    }

    if (_matchState == _MatchState.queued || _matchState == _MatchState.connecting || _matchState == _MatchState.discovering) {
      return _ActionButton(
        label: l10n.cancelMatching,
        icon: Icons.close,
        color: Colors.redAccent,
        onTap: _cancelMatchmaking,
      );
    }

    return const SizedBox.shrink();
  }
}

class _MatchingParticle extends StatelessWidget {
  final int index;
  final AnimationController controller;
  const _MatchingParticle({required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    final rng = Random(index);
    final startX = rng.nextDouble();
    final speed = 0.3 + rng.nextDouble() * 0.5;
    final size = 1.5 + rng.nextDouble() * 3;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value * speed + index * 0.1) % 1.0;
        final screen = MediaQuery.of(context).size;
        return Positioned(
          left: startX * screen.width,
          top: (1.0 - t) * screen.height,
          child: Opacity(
            opacity: (0.2 + 0.3 * sin(t * pi)).clamp(0.0, 1.0),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color.withValues(alpha: 0.15),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// Simple AnimatedBuilder wrapper (same pattern as main_menu)
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;
  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) => builder(context, child);
}
