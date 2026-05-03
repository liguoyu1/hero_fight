import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Creates an IOWebSocketChannel (native dart:io).
WebSocketChannel createChannel(String url) {
  return IOWebSocketChannel.connect(Uri.parse(url));
}
