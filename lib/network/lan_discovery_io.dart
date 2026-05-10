import 'dart:io';

/// Bind a UDP broadcast socket for LAN discovery.
/// Tries IPv4 first, falls back to IPv6 for App Store review networks.
Future<RawDatagramSocket> bindUdpDiscoveryBroadcast() async {
  try {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    return socket;
  } catch (_) {
    // IPv6-only network (App Store review): use IPv6
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
    return socket; // No broadcast on IPv6 — LAN discovery will be limited
  }
}

/// The event value for \"data available to read\".
// ignore: non_constant_identifier_names
dynamic get rawSocketEventRead => RawSocketEvent.read;

/// The broadcast address for LAN discovery.
InternetAddress broadcastAddress() => InternetAddress('255.255.255.255');
