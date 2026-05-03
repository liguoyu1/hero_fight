import 'package:flutter_test/flutter_test.dart';
import 'package:hero_fighter/game/components/fighter.dart';
import 'package:hero_fighter/game/network/game_snapshot.dart';

// Minimal mock to test RollbackEngine buffer logic without full game
class MockFighterData {
  Map<String, dynamic> toJson() => {'x': 0.0, 'y': 0.0, 'hp': 100};
  void fromJson(Map<String, dynamic> json) {}
}

void main() {
  // ─── FighterInput Tests ───
  group('FighterInput - Constructor & Properties', () {
    test('empty constructor creates input with all false values', () {
      final input = FighterInput.empty();

      expect(input.left, isFalse);
      expect(input.right, isFalse);
      expect(input.up, isFalse);
      expect(input.down, isFalse);
      expect(input.jump, isFalse);
      expect(input.attack, isFalse);
      expect(input.skill, isFalse);
      expect(input.frame, equals(-1));
    });

    test('named constructor accepts all parameters', () {
      final input = FighterInput(
        left: true,
        right: false,
        up: true,
        down: false,
        jump: true,
        attack: false,
        skill: true,
        frame: 42,
      );

      expect(input.left, isTrue);
      expect(input.right, isFalse);
      expect(input.up, isTrue);
      expect(input.down, isFalse);
      expect(input.jump, isTrue);
      expect(input.attack, isFalse);
      expect(input.skill, isTrue);
      expect(input.frame, equals(42));
    });

    test('default values for optional parameters', () {
      final input = FighterInput();

      expect(input.left, isFalse);
      expect(input.right, isFalse);
      expect(input.up, isFalse);
      expect(input.down, isFalse);
      expect(input.jump, isFalse);
      expect(input.attack, isFalse);
      expect(input.skill, isFalse);
      expect(input.frame, equals(-1));
    });
  });

  group('FighterInput - copy()', () {
    test('copy creates independent instance', () {
      final original = FighterInput(
        left: true,
        right: true,
        up: false,
        down: true,
        jump: false,
        attack: true,
        skill: false,
        frame: 100,
      );

      final copied = original.copy();

      // Verify it's a different object
      expect(identical(original, copied), isFalse);

      // Verify values are copied
      expect(copied.left, isTrue);
      expect(copied.right, isTrue);
      expect(copied.up, isFalse);
      expect(copied.down, isTrue);
      expect(copied.jump, isFalse);
      expect(copied.attack, isTrue);
      expect(copied.skill, isFalse);
      expect(copied.frame, equals(100));
    });

    test('copy does not affect original when modified', () {
      final original = FighterInput(left: true, frame: 10);
      final copied = original.copy();

      // Modify copy
      copied.left = false;
      copied.frame = 999;

      // Original should be unchanged
      expect(original.left, isTrue);
      expect(original.frame, equals(10));
    });

    test('copy of empty input works correctly', () {
      final empty = FighterInput.empty();
      final copied = empty.copy();

      expect(copied.left, isFalse);
      expect(copied.right, isFalse);
      expect(copied.frame, equals(-1));
    });
  });

  group('FighterInput - copyFrom()', () {
    test('copyFrom copies all button states', () {
      final target = FighterInput.empty();
      final source = FighterInput(
        left: true,
        right: false,
        up: true,
        down: false,
        jump: true,
        attack: false,
        skill: true,
      );

      target.copyFrom(source);

      expect(target.left, isTrue);
      expect(target.right, isFalse);
      expect(target.up, isTrue);
      expect(target.down, isFalse);
      expect(target.jump, isTrue);
      expect(target.attack, isFalse);
      expect(target.skill, isTrue);
    });

    test('copyFrom preserves target frame', () {
      final target = FighterInput(frame: 50);
      final source = FighterInput(frame: 100);

      target.copyFrom(source);

      // copyFrom does NOT copy frame, so target.frame stays unchanged
      expect(target.frame, equals(50));
    });

    test('copyFrom can overwrite previous values', () {
      final target = FighterInput(
        left: true,
        right: true,
        attack: true,
      );
      final source = FighterInput(
        left: false,
        right: false,
        attack: false,
      );

      target.copyFrom(source);

      expect(target.left, isFalse);
      expect(target.right, isFalse);
      expect(target.attack, isFalse);
    });
  });

  group('FighterInput - frame property', () {
    test('frame defaults to -1', () {
      final input = FighterInput();
      expect(input.frame, equals(-1));
    });

    test('frame can be set directly', () {
      final input = FighterInput();
      input.frame = 123;
      expect(input.frame, equals(123));
    });

    test('frame is copied in copy()', () {
      final original = FighterInput(frame: 999);
      final copied = original.copy();
      expect(copied.frame, equals(999));
    });
  });

  // ─── GameSnapshot Tests ───
  group('GameSnapshot - Serialization', () {
    test('toJson produces correct map structure', () {
      final snapshot = GameSnapshot(
        frameNumber: 42,
        fighter1: {'x': 100.0, 'y': 200.0, 'hp': 500},
        fighter2: {'x': 300.0, 'y': 200.0, 'hp': 750},
        projectiles: [
          {'x': 150.0, 'y': 180.0, 'damage': 20}
        ],
        prngState: 12345,
        roundTimer: 99.5,
        gameState: 'fighting',
        winnerName: null,
      );

      final json = snapshot.toJson();

      expect(json['frame'], equals(42));
      expect(json['fighter1'], equals({'x': 100.0, 'y': 200.0, 'hp': 500}));
      expect(json['fighter2'], equals({'x': 300.0, 'y': 200.0, 'hp': 750}));
      expect(json['projectiles'], isA<List>());
      expect((json['projectiles'] as List).length, equals(1));
      expect(json['prng'], equals(12345));
      expect(json['roundTimer'], equals(99.5));
      expect(json['gameState'], equals('fighting'));
      expect(json['winnerName'], isNull);
    });

    test('fromJson restores all fields correctly', () {
      final originalJson = {
        'frame': 100,
        'fighter1': {'x': 50.0, 'y': 100.0, 'hp': 300},
        'fighter2': {'x': 400.0, 'y': 100.0, 'hp': 600},
        'projectiles': [
          {'x': 200.0, 'y': 150.0, 'damage': 15},
          {'x': 250.0, 'y': 140.0, 'damage': 25},
        ],
        'prng': 98765,
        'roundTimer': 45.5,
        'gameState': 'paused',
        'winnerName': 'Player1',
      };

      final snapshot = GameSnapshot.fromJson(originalJson);

      expect(snapshot.frameNumber, equals(100));
      expect(snapshot.fighter1['x'], equals(50.0));
      expect(snapshot.fighter1['y'], equals(100.0));
      expect(snapshot.fighter1['hp'], equals(300));
      expect(snapshot.fighter2['x'], equals(400.0));
      expect(snapshot.projectiles.length, equals(2));
      expect(snapshot.prngState, equals(98765));
      expect(snapshot.roundTimer, equals(45.5));
      expect(snapshot.gameState, equals('paused'));
      expect(snapshot.winnerName, equals('Player1'));
    });

    test('toJson and fromJson roundtrip preserves data', () {
      final original = GameSnapshot(
        frameNumber: 77,
        fighter1: {'x': 10.0, 'y': 20.0, 'hp': 111},
        fighter2: {'x': 30.0, 'y': 40.0, 'hp': 222},
        projectiles: <Map<String, dynamic>>[],
        prngState: 55555,
        roundTimer: 88.8,
        gameState: 'fighting',
        winnerName: 'CPU',
      );

      final json = original.toJson();
      final restored = GameSnapshot.fromJson(json);

      expect(restored.frameNumber, equals(original.frameNumber));
      expect(restored.fighter1, equals(original.fighter1));
      expect(restored.fighter2, equals(original.fighter2));
      expect(restored.projectiles, equals(original.projectiles));
      expect(restored.prngState, equals(original.prngState));
      expect(restored.roundTimer, equals(original.roundTimer));
      expect(restored.gameState, equals(original.gameState));
      expect(restored.winnerName, equals(original.winnerName));
    });

    test('fromJson handles empty projectiles list', () {
      final json = {
        'frame': 10,
        'fighter1': <String, dynamic>{},
        'fighter2': <String, dynamic>{},
        'projectiles': <dynamic>[],
        'prng': 0,
        'roundTimer': 60.0,
        'gameState': 'fighting',
        'winnerName': null,
      };

      final snapshot = GameSnapshot.fromJson(json);

      expect(snapshot.projectiles, isEmpty);
    });

    test('fromJson handles integer roundTimer', () {
      final json = {
        'frame': 10,
        'fighter1': <String, dynamic>{},
        'fighter2': <String, dynamic>{},
        'projectiles': <dynamic>[],
        'prng': 0,
        'roundTimer': 60, // integer instead of double
        'gameState': 'fighting',
        'winnerName': null,
      };

      final snapshot = GameSnapshot.fromJson(json);

      expect(snapshot.roundTimer, equals(60.0));
    });
  });

  // Note: RollbackEngine requires FighterGame which is complex to instantiate.
  // We cannot test it directly without significant mocking.
  // The tests above cover the core data structures (FighterInput, GameSnapshot)
  // that RollbackEngine depends on.
}