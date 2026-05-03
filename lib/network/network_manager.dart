import 'dart:async';

import 'game_client.dart';

/// Connection state for the network manager.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Discovered LAN server info.
class LanServer {
  final String address;
  final int port;
  final String name;
  final int roomCount;

  LanServer({
    required this.address,
    required this.port,
    required this.name,
    required this.roomCount,
  });

  String get url => 'ws://$address:$port';
}

/// High-level network manager wrapping GameClient.
/// Provides callbacks and manages connection state.
class NetworkManager {
  final GameClient _client = GameClient();
  final List<StreamSubscription> _subs = [];

  ConnectionState _state = ConnectionState.disconnected;
  String? _currentRoomId;
  int _mySlot = -1;
  final List<LanServer> _discoveredServers = [];

  // Callbacks
  void Function(ConnectionState state)? onConnectionStateChanged;
  void Function(String clientId)? onConnected;
  void Function(String reason)? onDisconnected;
  void Function(String message)? onError;
  void Function(List<dynamic> rooms)? onRoomListReceived;
  void Function(Map<String, dynamic> data)? onRoomCreated;
  void Function(Map<String, dynamic> data)? onRoomJoined;
  void Function()? onRoomLeft;
  void Function(Map<String, dynamic> data)? onPlayerJoined;
  void Function(Map<String, dynamic> data)? onPlayerLeft;
  void Function(Map<String, dynamic> data)? onHeroSelected;
  void Function(Map<String, dynamic> data)? onPlayerReady;
  void Function(Map<String, dynamic> data)? onGameStart;
  void Function(Map<String, dynamic> data)? onGameInput;
  void Function(Map<String, dynamic> data)? onGameEnd;
  void Function(LanServer server)? onLanServerFound;
  void Function(Map<String, dynamic> status)? onMatchmakingStatus;
  void Function(Map<String, dynamic> data)? onMatchFound;

  // Public getters
  ConnectionState get state => _state;
  bool get isConnected => _state == ConnectionState.connected;
  String? get clientId => _client.clientId;
  String? get deviceId => _client.deviceId;
  String? get currentRoomId => _currentRoomId;
  int get mySlot => _mySlot;
  List<LanServer> get discoveredServers => List.unmodifiable(_discoveredServers);

  // Stream-based API (for reactive consumption during gameplay)
  Stream<Map<String, dynamic>> get onGameInputStream => _client.onGameInput;
  Stream<Map<String, dynamic>> get onGameEndStream => _client.onGameEnd;
  Stream<String> get onDisconnectedStream => _client.onDisconnected;
  Stream<String> get onErrorStream => _client.onError;

  NetworkManager() {
    _setupListeners();
  }

  void _setState(ConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    onConnectionStateChanged?.call(_state);
  }

  void _setupListeners() {
    _subs.add(_client.onConnected.listen((id) {
      _setState(ConnectionState.connected);
      onConnected?.call(id);
    }));

    _subs.add(_client.onDisconnected.listen((reason) {
      _setState(ConnectionState.disconnected);
      _currentRoomId = null;
      _mySlot = -1;
      onDisconnected?.call(reason);
    }));

    _subs.add(_client.onError.listen((msg) {
      onError?.call(msg);
    }));

    _subs.add(_client.onRoomList.listen((rooms) {
      onRoomListReceived?.call(rooms);
    }));

    _subs.add(_client.onRoomCreated.listen((data) {
      _currentRoomId = (data['room'] as Map<String, dynamic>?)?['id'] as String?;
      _mySlot = data['slot'] as int? ?? 0;
      onRoomCreated?.call(data);
    }));

    _subs.add(_client.onRoomJoined.listen((data) {
      _currentRoomId = (data['room'] as Map<String, dynamic>?)?['id'] as String?;
      _mySlot = data['slot'] as int? ?? 1;
      onRoomJoined?.call(data);
    }));

    _subs.add(_client.onRoomLeft.listen((_) {
      _currentRoomId = null;
      _mySlot = -1;
      onRoomLeft?.call();
    }));

    _subs.add(_client.onPlayerJoined.listen((d) => onPlayerJoined?.call(d)));
    _subs.add(_client.onPlayerLeft.listen((d) => onPlayerLeft?.call(d)));
    _subs.add(_client.onHeroSelected.listen((d) => onHeroSelected?.call(d)));
    _subs.add(_client.onPlayerReady.listen((d) => onPlayerReady?.call(d)));
    _subs.add(_client.onGameStart.listen((d) => onGameStart?.call(d)));
    _subs.add(_client.onGameInput.listen((d) => onGameInput?.call(d)));
    _subs.add(_client.onGameEnd.listen((d) {
      _currentRoomId = null;
      onGameEnd?.call(d);
    }));

    _subs.add(_client.onMatchmakingStatus.listen((data) {
      onMatchmakingStatus?.call(data);
    }));
    _subs.add(_client.onMatchFound.listen((data) {
      _currentRoomId = (data['room'] as Map<String, dynamic>?)?['id'] as String?;
      _mySlot = data['slot'] as int? ?? 0;
      onMatchFound?.call(data);
    }));
    _subs.add(_client.onLanServerFound.listen((data) {
      final server = LanServer(
        address: data['address'] as String? ?? '',
        port: data['port'] as int? ?? 3000,
        name: data['name'] as String? ?? 'Unknown',
        roomCount: data['rooms'] as int? ?? 0,
      );
      // Avoid duplicates
      if (!_discoveredServers.any((s) => s.address == server.address && s.port == server.port)) {
        _discoveredServers.add(server);
        onLanServerFound?.call(server);
      }
    }));
  }

  // --- Connection ---
  Future<void> connect(String url) async {
    _setState(ConnectionState.connecting);
    await _client.connect(url);
  }

  Future<void> connectToLanServer(LanServer server) async {
    await connect(server.url);
  }

  void disconnect() {
    _client.disconnect();
    _currentRoomId = null;
    _mySlot = -1;
    _setState(ConnectionState.disconnected);
  }

  // --- Room actions ---
  void requestRoomList() => _client.requestRoomList();
  void createRoom({String? name, String? playerName}) =>
      _client.createRoom(name: name, playerName: playerName);
  void joinRoom(String roomId, {String? playerName}) =>
      _client.joinRoom(roomId, playerName: playerName);
  void leaveRoom() => _client.leaveRoom();

  // --- Hero & ready ---
  void selectHero(String heroId) => _client.selectHero(heroId);
  void sendReady({bool ready = true}) => _client.sendReady(ready: ready);

  // --- Game ---
  void sendInput(int frame, Map<String, dynamic> inputs) =>
      _client.sendInput(frame, inputs);
  void sendGameEnd({String? reason, String? winnerId}) =>
      _client.sendGameEnd(reason: reason, winnerId: winnerId);

  // --- LAN Discovery ---
  Future<void> discoverLanServers() async {
    _discoveredServers.clear();
    await _client.discoverLanServers();
  }

  // --- Matchmaking ---
  void requestMatchmaking({String? playerName}) =>
      _client.requestMatchmaking(playerName: playerName);
  void cancelMatchmaking() => _client.cancelMatchmaking();

  /// Dispose all resources.
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _client.dispose();
  }
}
