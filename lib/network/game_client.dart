import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_channel.dart';
import '../data/device_id.dart';
import '../data/nickname.dart';

import 'lan_discovery_stub.dart' if (dart.library.io) 'lan_discovery_io.dart';

/// Low-level WebSocket client for Hero Fighter game server.
class GameClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _lanDiscoveryTimer;
  final Random _random = Random();

  String? _serverUrl;
  String? _clientId;
  String? _deviceId;
  bool _connected = false;
  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  // Stream controllers for events
  final _onConnected = StreamController<String>.broadcast();
  final _onDisconnected = StreamController<String>.broadcast();
  final _onError = StreamController<String>.broadcast();
  final _onRoomList = StreamController<List<dynamic>>.broadcast();
  final _onRoomCreated = StreamController<Map<String, dynamic>>.broadcast();
  final _onRoomJoined = StreamController<Map<String, dynamic>>.broadcast();
  final _onRoomLeft = StreamController<String?>.broadcast();
  final _onPlayerJoined = StreamController<Map<String, dynamic>>.broadcast();
  final _onPlayerLeft = StreamController<Map<String, dynamic>>.broadcast();
  final _onHeroSelected = StreamController<Map<String, dynamic>>.broadcast();
  final _onPlayerReady = StreamController<Map<String, dynamic>>.broadcast();
  final _onGameStart = StreamController<Map<String, dynamic>>.broadcast();
  final _onGameInput = StreamController<Map<String, dynamic>>.broadcast();
  final _onGameEnd = StreamController<Map<String, dynamic>>.broadcast();
  final _onLanServerFound = StreamController<Map<String, dynamic>>.broadcast();
  final _onMatchmakingStatus = StreamController<Map<String, dynamic>>.broadcast();
  final _onMatchFound = StreamController<Map<String, dynamic>>.broadcast();
  final _onMessage = StreamController<Map<String, dynamic>>.broadcast();

  // Public getters
  String? get clientId => _clientId;
  String? get deviceId => _deviceId;
  bool get isConnected => _connected;
  String? get serverUrl => _serverUrl;

  // Event streams
  Stream<String> get onConnected => _onConnected.stream;
  Stream<String> get onDisconnected => _onDisconnected.stream;
  Stream<String> get onError => _onError.stream;
  Stream<List<dynamic>> get onRoomList => _onRoomList.stream;
  Stream<Map<String, dynamic>> get onRoomCreated => _onRoomCreated.stream;
  Stream<Map<String, dynamic>> get onRoomJoined => _onRoomJoined.stream;
  Stream<String?> get onRoomLeft => _onRoomLeft.stream;
  Stream<Map<String, dynamic>> get onPlayerJoined => _onPlayerJoined.stream;
  Stream<Map<String, dynamic>> get onPlayerLeft => _onPlayerLeft.stream;
  Stream<Map<String, dynamic>> get onHeroSelected => _onHeroSelected.stream;
  Stream<Map<String, dynamic>> get onPlayerReady => _onPlayerReady.stream;
  Stream<Map<String, dynamic>> get onGameStart => _onGameStart.stream;
  Stream<Map<String, dynamic>> get onGameInput => _onGameInput.stream;
  Stream<Map<String, dynamic>> get onGameEnd => _onGameEnd.stream;
  Stream<Map<String, dynamic>> get onLanServerFound =>
      _onLanServerFound.stream;
  Stream<Map<String, dynamic>> get onMatchmakingStatus =>
      _onMatchmakingStatus.stream;
  Stream<Map<String, dynamic>> get onMatchFound =>
      _onMatchFound.stream;
  Stream<Map<String, dynamic>> get onMessage => _onMessage.stream;

  /// Connect to the game server via WebSocket.
  Future<void> connect(String url, {bool autoReconnect = true}) async {
    _serverUrl = url;
    _autoReconnect = autoReconnect;
    _reconnectAttempts = 0;
    
    // 确保有 deviceId
    if (_deviceId == null) {
      try {
        _deviceId = await getDeviceId();
        print('Device ID obtained: $_deviceId');
      } catch (e) {
        // 如果获取失败，生成随机 ID
        _deviceId = 'random_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(999999)}';
        print('Failed to get device ID, using random: $_deviceId');
      }
    }
    
    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      disconnect(permanent: false);
      // 直接使用传入的 URL（已经是 ws:// 或 wss://）
      final wsUrl = _serverUrl!;
      print('Connecting to: $wsUrl'); // 调试日志
      _channel = createChannel(wsUrl);
      _subscription = _channel!.stream.listen(
        _onData,
        onError: _onWsError,
        onDone: _onWsDone,
      );
    } catch (e) {
      _onError.add('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      _onMessage.add(msg);

      switch (type) {
        case 'connected':
          _clientId = msg['clientId'] as String?;
          _connected = true;
          _reconnectAttempts = 0;
          if (_deviceId != null) {
            getNickname().then((nick) {
              _send({
                'type': 'register_device',
                'deviceId': _deviceId,
                'nickname': nick ?? 'Player',
              });
            });
          }
          _onConnected.add(_clientId ?? '');
          break;
        case 'error':
          _onError.add(msg['message'] as String? ?? 'Unknown error');
          break;
        case 'room_list':
          _onRoomList.add(msg['rooms'] as List<dynamic>? ?? []);
          break;
        case 'room_created':
          _onRoomCreated.add(msg);
          break;
        case 'room_joined':
          _onRoomJoined.add(msg);
          break;
        case 'room_left':
          _onRoomLeft.add(msg['roomId'] as String?);
          break;
        case 'player_joined':
          _onPlayerJoined.add(msg);
          break;
        case 'player_left':
          _onPlayerLeft.add(msg);
          break;
        case 'hero_selected':
          _onHeroSelected.add(msg);
          break;
        case 'player_ready':
          _onPlayerReady.add(msg);
          break;
        case 'game_start':
          _onGameStart.add(msg);
          break;
        case 'game_input':
          _onGameInput.add(msg);
          break;
        case 'game_end':
          _onGameEnd.add(msg);
          break;
        case 'matchmaking_status':
          _onMatchmakingStatus.add(msg);
          break;
        case 'match_found':
          _onMatchFound.add(msg);
          break;
        case 'server_shutdown':
          _onDisconnected.add('Server shutting down');
          break;
      }
    } catch (e) {
      _onError.add('Parse error: $e');
    }
  }

  void _onWsError(dynamic error) {
    _connected = false;
    _onError.add('WebSocket error: $error');
    _scheduleReconnect();
  }

  void _onWsDone() {
    _connected = false;
    _onDisconnected.add('Connection closed');
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_autoReconnect || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    _reconnectTimer = Timer(_reconnectDelay * _reconnectAttempts, _doConnect);
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(msg));
    }
  }

  /// Disconnect from the server.
  void disconnect({bool permanent = true}) {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    if (permanent) {
      _autoReconnect = false;
      _connected = false;
      _clientId = null;
    }
  }

  // --- Room actions ---
  void requestRoomList() => _send({'type': 'room_list'});

  void createRoom({String? name, String? playerName}) => _send({
        'type': 'create_room',
        if (name != null) 'name': name,
        if (playerName != null) 'playerName': playerName,
      });

  void joinRoom(String roomId, {String? playerName}) => _send({
        'type': 'join_room',
        'roomId': roomId,
        if (playerName != null) 'playerName': playerName,
      });

  void leaveRoom() => _send({'type': 'leave_room'});

  // --- Hero selection ---
  void selectHero(String heroId) =>
      _send({'type': 'select_hero', 'heroId': heroId});

  void sendReady({bool ready = true}) =>
      _send({'type': 'player_ready', 'ready': ready});

  // --- Game actions ---
  void sendInput(int frame, Map<String, dynamic> inputs) =>
      _send({'type': 'game_input', 'frame': frame, 'inputs': inputs});

  void sendGameEnd({String? reason, String? winnerId}) => _send({
        'type': 'game_end',
        if (reason != null) 'reason': reason,
        if (winnerId != null) 'winnerId': winnerId,
      });

  // --- Matchmaking ---
  void requestMatchmaking({String? playerName}) =>
      _send({'type': 'start_matchmaking', if (playerName != null) 'playerName': playerName});
  void cancelMatchmaking() => _send({'type': 'cancel_matchmaking'});

  // --- LAN Discovery ---
  /// Discovers LAN servers via UDP broadcast.
  /// On web, LAN discovery is not supported (UDP requires dart:io).
  Future<void> discoverLanServers({
    int port = 3001,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (kIsWeb) {
      _onError.add('LAN discovery not available on web');
      return;
    }
    _lanDiscoveryTimer?.cancel();
    try {
      final socket = await bindUdpDiscoveryBroadcast();
      final msg = utf8.encode(jsonEncode({'type': 'lan_discover'}));

      // Send discovery broadcast to 255.255.255.255 on the target port
      socket.send(msg, broadcastAddress(), port);

      socket.listen((event) {
        if (event == rawSocketEventRead) {
          // ignore: avoid_dynamic_calls
          final dg = socket.receive();
          if (dg != null) {
            try {
              final data = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
              if (data['type'] == 'lan_discover_response') {
                data['address'] = dg.address.address;
                _onLanServerFound.add(data);
              }
            } catch (_) {}
          }
        }
      });

      _lanDiscoveryTimer = Timer(timeout, () {
        socket.close();
      });
    } catch (e) {
      _onError.add('LAN discovery failed: $e');
    }
  }

  /// Dispose all resources.
  void dispose() {
    disconnect();
    _lanDiscoveryTimer?.cancel();
    _onConnected.close();
    _onDisconnected.close();
    _onError.close();
    _onRoomList.close();
    _onRoomCreated.close();
    _onRoomJoined.close();
    _onRoomLeft.close();
    _onPlayerJoined.close();
    _onPlayerLeft.close();
    _onHeroSelected.close();
    _onPlayerReady.close();
    _onGameStart.close();
    _onGameInput.close();
    _onGameEnd.close();
    _onLanServerFound.close();
    _onMatchmakingStatus.close();
    _onMatchFound.close();
    _onMessage.close();
  }
}
