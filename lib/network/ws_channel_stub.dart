import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates a platform-appropriate WebSocketChannel.
/// Stub: throws UnsupportedError (no WebSocket on this platform).
WebSocketChannel createChannel(String url) {
  throw UnsupportedError('WebSocket not available on this platform');
}
