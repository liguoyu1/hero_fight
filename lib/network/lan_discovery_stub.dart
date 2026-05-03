// Stub for web platform — LAN discovery not supported.
//
// These symbols exist but throw [UnsupportedError] when called.
// They exist only to satisfy compile-time type resolution on web.

/// Bind a UDP broadcast socket for LAN discovery.
/// On web, this always throws [UnsupportedError].
Future<dynamic> bindUdpDiscoveryBroadcast() async {
  throw UnsupportedError('LAN discovery not supported on this platform');
}

/// The event value for "data available to read" (RawSocketEvent.read).
/// On web, this is just a placeholder that is never actually used.
// ignore: non_constant_identifier_names
dynamic get rawSocketEventRead => null;

/// Broadcast address stub — never called on web.
dynamic broadcastAddress() =>
    throw UnsupportedError('LAN discovery not supported on this platform');
