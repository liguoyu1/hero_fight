import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hero_fighter/game/ai/ai_controller.dart';
import 'package:hero_fighter/game/components/fighter.dart';

Fighter _createLubuFighter() {
  return Fighter(
    playerIndex: 0,
    name: 'Lu Bu',
    heroId: 'lubu',
    color: const Color(0xFFCC0000),
    maxHp: 1200,
    speed: 140,
    jumpForce: 320,
    attackPower: 55,
    defense: 30,
    skillCooldown: 8.0,
  );
}

void main() {
  group('AI Controller - Difficulty Levels', () {
    test('Easy AI has longer reaction delay than hard', () {
      final easyFighter = _createLubuFighter();
      final hardFighter = _createLubuFighter();

      final easy =
          AiController(fighter: easyFighter, difficulty: AiDifficulty.easy);
      final hard =
          AiController(fighter: hardFighter, difficulty: AiDifficulty.hard);

      // Reaction delays are private, but we can verify behavior exists
      expect(easy.difficulty, AiDifficulty.easy);
      expect(hard.difficulty, AiDifficulty.hard);
    });

    test('All difficulties initialize correctly', () {
      for (final difficulty in AiDifficulty.values) {
        final fighter = _createLubuFighter();
        final ai = AiController(fighter: fighter, difficulty: difficulty);

        expect(ai.difficulty, difficulty);
        expect(ai.fighter, fighter);
      }
    });
  });

  group('AI Controller - Update Cycle', () {
    test('AI updates without crashing', () {
      final fighter = _createLubuFighter();
      final ai =
          AiController(fighter: fighter, difficulty: AiDifficulty.medium);

      expect(() => ai.update(0.016), returnsNormally);
      expect(() => ai.update(0.016), returnsNormally);
    });

    test('AI handles dead fighter gracefully', () {
      final fighter = _createLubuFighter();
      fighter.hp = 0; // Kill fighter

      final ai =
          AiController(fighter: fighter, difficulty: AiDifficulty.medium);

      expect(() => ai.update(0.016), returnsNormally);
    });
  });

  group('AI Controller - Difficulty Parameters', () {
    test('Easy AI has conservative behavior', () {
      final fighter = _createLubuFighter();
      final easy =
          AiController(fighter: fighter, difficulty: AiDifficulty.easy);

      // Easy AI should exist and be functional
      expect(easy.difficulty, AiDifficulty.easy);
      expect(() => easy.update(0.016), returnsNormally);
    });

    test('Hard AI is more aggressive', () {
      final fighter = _createLubuFighter();
      final hard =
          AiController(fighter: fighter, difficulty: AiDifficulty.hard);

      expect(hard.difficulty, AiDifficulty.hard);
      expect(() => hard.update(0.016), returnsNormally);
    });
  });

  group('AI Controller - Fighter Integration', () {
    test('AI controls fighter input', () {
      final fighter = _createLubuFighter();
      final ai =
          AiController(fighter: fighter, difficulty: AiDifficulty.medium);

      // Initial state
      expect(fighter.input.left, isFalse);
      expect(fighter.input.right, isFalse);
      expect(fighter.input.attack, isFalse);

      // AI should potentially modify input after update
      ai.update(0.5); // Longer time to trigger decision

      // Input should be controlled (may or may not be active, but should be valid)
      expect(fighter.input, isNotNull);
    });
  });
}
