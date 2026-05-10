import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  final secret = 'hero-fighter-secret-key-2024';

  final data = {
    'gameMode': 'ai',
    'player1Hero': 'warrior',
    'player1Id': 'device123',
    'player1Name': 'TestPlayer',
    'player2Hero': 'mage',
    'player2Id': 'ai_device123',
    'player2Name': 'AI',
    'winnerId': 'device123'
  };

  final payload = json.encode(data);
  final key = utf8.encode(secret);
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(utf8.encode(payload));

  print('Payload: $payload');
  print('Signature: $digest');
  print('Expected:  b7aa7cb7fbbd5077a4f7089041b3a47d52add6b7e9064039fccc474c467a2e49');
  print('Match: ${digest.toString() == 'b7aa7cb7fbbd5077a4f7089041b3a47d52add6b7e9064039fccc474c467a2e49'}');
}
