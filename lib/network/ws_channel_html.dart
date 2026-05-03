import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';

/// Creates an HtmlWebSocketChannel (web platform).
WebSocketChannel createChannel(String url) {
  return HtmlWebSocketChannel.connect(url);
}
