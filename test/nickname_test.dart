import 'package:flutter_test/flutter_test.dart';
import 'package:hero_fighter/data/nickname.dart';

void main() {
  group('buildDisplayName', () {
    test('appends last 4 chars of deviceId', () {
      expect(buildDisplayName('Hero', 'abcd1234'), 'Hero#1234');
    });

    test('handles short deviceId (< 4 chars)', () {
      expect(buildDisplayName('Hero', 'ab'), 'Hero#ab');
    });

    test('handles exactly 4 char deviceId', () {
      expect(buildDisplayName('Hero', 'wxyz'), 'Hero#wxyz');
    });

    test('handles empty nickname', () {
      expect(buildDisplayName('', 'abcd1234'), '#1234');
    });

    test('handles empty deviceId', () {
      expect(buildDisplayName('Hero', ''), 'Hero#');
    });

    test('handles unicode nickname', () {
      expect(buildDisplayName('吕布', 'abcd1234'), '吕布#1234');
    });

    test('handles long deviceId', () {
      expect(
        buildDisplayName('Test', 'a1b2c3d4e5f6'),
        'Test#e5f6',
      );
    });
  });

  group('maxNicknameLength', () {
    test('is 8', () {
      expect(maxNicknameLength, 8);
    });
  });
}
