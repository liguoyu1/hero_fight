// Conditional import: selects the right WebSocketChannel implementation
// based on the platform.
export 'ws_channel_stub.dart' if (dart.library.io) 'ws_channel_io.dart'
    if (dart.library.html) 'ws_channel_html.dart';
