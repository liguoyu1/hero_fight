import 'package:flutter_test/flutter_test.dart';
import 'package:hero_fighter/network/network_manager.dart';

void main() {
  group('LanServer', () {
    test('url getter returns ws:// format', () {
      final server = LanServer(
        address: '192.168.1.100',
        port: 3000,
        name: 'Test Server',
        roomCount: 2,
      );
      expect(server.url, 'ws://192.168.1.100:3000');
    });

    test('stores all fields correctly', () {
      final server = LanServer(
        address: '10.0.0.1',
        port: 8080,
        name: 'My Server',
        roomCount: 5,
      );
      expect(server.address, '10.0.0.1');
      expect(server.port, 8080);
      expect(server.name, 'My Server');
      expect(server.roomCount, 5);
    });

    test('url with localhost', () {
      final server = LanServer(
        address: 'localhost',
        port: 3000,
        name: 'Local',
        roomCount: 0,
      );
      expect(server.url, 'ws://localhost:3000');
    });

    test('url with non-standard port', () {
      final server = LanServer(
        address: '192.168.0.1',
        port: 9999,
        name: 'Custom',
        roomCount: 1,
      );
      expect(server.url, 'ws://192.168.0.1:9999');
    });
  });

  group('ConnectionState', () {
    test('has all expected values', () {
      expect(ConnectionState.values.length, 5);
      expect(ConnectionState.values, contains(ConnectionState.disconnected));
      expect(ConnectionState.values, contains(ConnectionState.connecting));
      expect(ConnectionState.values, contains(ConnectionState.connected));
      expect(ConnectionState.values, contains(ConnectionState.reconnecting));
      expect(ConnectionState.values, contains(ConnectionState.error));
    });
  });
}
