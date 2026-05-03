import 'dart:io';

/// Bind a UDP broadcast socket for LAN discovery.
/// Returns the bound RawDatagramSocket.
Future<RawDatagramSocket> bindUdpDiscoveryBroadcast() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true;
  return socket;
}

/// The event value for "data available to read".
// ignore: non_constant_identifier_names
dynamic get rawSocketEventRead => RawSocketEvent.read;

/// The broadcast address for LAN discovery.
InternetAddress broadcastAddress() => InternetAddress('255.255.255.255');
