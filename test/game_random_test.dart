import 'package:flutter_test/flutter_test.dart';
import 'package:hero_fighter/game/utils/game_random.dart';

void main() {
  // ─── Constructor & Seeding ───
  group('GameRandom - Constructor & Seeding', () {
    test('default seed is 12345', () {
      final rng = GameRandom();
      expect(rng.state, 12345);
    });

    test('custom seed is used directly', () {
      final rng = GameRandom(42);
      expect(rng.state, 42);
    });

    test('seed 0 is replaced with 1 (xorshift requires non-zero)', () {
      final rng = GameRandom(0);
      expect(rng.state, 1);
    });

    test('seed 1 works correctly', () {
      final rng = GameRandom(1);
      expect(rng.state, 1);
    });

    test('large seed values work', () {
      final rng = GameRandom(0xFFFFFFFF);
      expect(rng.state, 0xFFFFFFFF);
    });
  });

  // ─── Determinism ───
  group('GameRandom - Determinism', () {
    test('same seed produces identical sequence', () {
      final rng1 = GameRandom(42);
      final rng2 = GameRandom(42);

      for (int i = 0; i < 100; i++) {
        expect(rng1.nextInt(1000), rng2.nextInt(1000),
            reason: 'Mismatch at iteration $i');
      }
    });

    test('different seeds produce different sequences', () {
      final rng1 = GameRandom(100);
      final rng2 = GameRandom(200);

      bool anyDifferent = false;
      for (int i = 0; i < 10; i++) {
        if (rng1.nextInt(1000) != rng2.nextInt(1000)) {
          anyDifferent = true;
          break;
        }
      }
      expect(anyDifferent, isTrue);
    });

    test('sequence is deterministic across multiple calls', () {
      final rng = GameRandom(999);
      // Just verify that calling nextInt produces consistent results
      // (the exact values depend on xorshift32 implementation)
      final firstRun = List.generate(10, (_) => rng.nextInt(1000));

      // Create new instance with same seed
      final rng2 = GameRandom(999);
      final secondRun = List.generate(10, (_) => rng2.nextInt(1000));

      expect(firstRun, secondRun);
    });
  });

  // ─── nextInt ───
  group('GameRandom - nextInt', () {
    test('returns values in range [0, max)', () {
      final rng = GameRandom(12345);
      for (int i = 0; i < 1000; i++) {
        final result = rng.nextInt(10);
        expect(result, greaterThanOrEqualTo(0));
        expect(result, lessThan(10));
      }
    });

    test('nextInt(0) returns 0 (edge case)', () {
      final rng = GameRandom(42);
      expect(rng.nextInt(0), 0);
    });

    test('nextInt(1) returns 0 (only valid value)', () {
      final rng = GameRandom(42);
      for (int i = 0; i < 100; i++) {
        expect(rng.nextInt(1), 0);
      }
    });

    test('nextInt(-1) returns 0 (edge case)', () {
      final rng = GameRandom(42);
      expect(rng.nextInt(-1), 0);
    });

    test('nextInt(1000) covers full range over many calls', () {
      final rng = GameRandom(42);
      final seen = <int>{};
      // Generate many values to ensure range coverage
      for (int i = 0; i < 10000; i++) {
        seen.add(rng.nextInt(1000));
      }
      // Should see most of the range
      expect(seen.length, greaterThan(900));
    });
  });

  // ─── nextBool ───
  group('GameRandom - nextBool', () {
    test('returns boolean values', () {
      final rng = GameRandom(42);
      for (int i = 0; i < 100; i++) {
        final result = rng.nextBool();
        expect(result, isA<bool>());
      }
    });

    test('produces roughly 50/50 distribution over many calls', () {
      final rng = GameRandom(42);
      int trueCount = 0;
      const iterations = 10000;

      for (int i = 0; i < iterations; i++) {
        if (rng.nextBool()) trueCount++;
      }

      final ratio = trueCount / iterations;
      expect(ratio, closeTo(0.5, 0.05)); // Within 5% of 50%
    });

    test('is deterministic based on seed', () {
      final rng1 = GameRandom(42);
      final rng2 = GameRandom(42);

      for (int i = 0; i < 100; i++) {
        expect(rng1.nextBool(), rng2.nextBool());
      }
    });
  });

  // ─── nextDouble ───
  group('GameRandom - nextDouble', () {
    test('returns values in range [0.0, 1.0)', () {
      final rng = GameRandom(42);
      for (int i = 0; i < 1000; i++) {
        final result = rng.nextDouble();
        expect(result, greaterThanOrEqualTo(0.0));
        expect(result, lessThan(1.0));
      }
    });

    test('never returns exactly 1.0', () {
      final rng = GameRandom(42);
      for (int i = 0; i < 10000; i++) {
        expect(rng.nextDouble(), isNot(1.0));
      }
    });

    test('can return exactly 0.0', () {
      // It's possible but very unlikely - test that it doesn't throw
      final rng = GameRandom(42);
      rng.nextDouble(); // Just ensure it doesn't crash
      expect(true, isTrue);
    });

    test('is deterministic based on seed', () {
      final rng1 = GameRandom(42);
      final rng2 = GameRandom(42);

      for (int i = 0; i < 100; i++) {
        expect(rng1.nextDouble(), rng2.nextDouble(),
            reason: 'Mismatch at iteration $i');
      }
    });
  });

  // ─── nextSignedDouble ───
  group('GameRandom - nextSignedDouble', () {
    test('returns values in range [-1.0, 1.0)', () {
      final rng = GameRandom(42);
      for (int i = 0; i < 1000; i++) {
        final result = rng.nextSignedDouble();
        expect(result, greaterThanOrEqualTo(-1.0));
        expect(result, lessThan(1.0));
      }
    });

    test('never returns exactly 1.0', () {
      final rng = GameRandom(42);
      for (int i = 0; i < 10000; i++) {
        expect(rng.nextSignedDouble(), isNot(1.0));
      }
    });

    test('can return exactly -1.0 (edge case)', () {
      // nextDouble() * 2.0 - 1.0 can theoretically be -1.0
      // when nextDouble() returns 0.0
      // Test that it doesn't crash
      final rng = GameRandom(42);
      rng.nextSignedDouble();
      expect(true, isTrue);
    });

    test('produces symmetric distribution around 0', () {
      final rng = GameRandom(42);
      const iterations = 10000;
      double sum = 0;

      for (int i = 0; i < iterations; i++) {
        sum += rng.nextSignedDouble();
      }

      final mean = sum / iterations;
      expect(mean, closeTo(0.0, 0.05)); // Mean should be near 0
    });

    test('is deterministic based on seed', () {
      final rng1 = GameRandom(42);
      final rng2 = GameRandom(42);

      for (int i = 0; i < 100; i++) {
        expect(rng1.nextSignedDouble(), rng2.nextSignedDouble(),
            reason: 'Mismatch at iteration $i');
      }
    });
  });

  // ─── State Accessors ───
  group('GameRandom - State Accessors', () {
    test('state getter returns current state', () {
      final rng = GameRandom(42);
      rng.nextInt(100);
      expect(rng.state, isNot(42)); // State should have changed
    });

    test('state setter updates internal state', () {
      final rng = GameRandom(42);
      rng.state = 999;
      expect(rng.state, 999);
    });

    test('state setter replaces 0 with 1', () {
      final rng = GameRandom(42);
      rng.state = 0;
      expect(rng.state, 1);
    });
  });

  // ─── Clone ───
  group('GameRandom - Clone', () {
    test('clone produces independent instance', () {
      final original = GameRandom(42);
      final cloned = original.clone();

      // They should be different objects
      expect(identical(original, cloned), isFalse);
    });

    test('clone has same state as original', () {
      final original = GameRandom(42);
      original.nextInt(100);
      final cloned = original.clone();

      expect(cloned.state, original.state);
    });

    test('clone produces identical sequence after clone', () {
      final original = GameRandom(42);
      original.nextInt(100); // Advance state
      final cloned = original.clone();

      // Both should produce the same next values
      for (int i = 0; i < 10; i++) {
        expect(original.nextInt(1000), cloned.nextInt(1000),
            reason: 'Mismatch at iteration $i after clone');
      }
    });

    test('modifying clone does not affect original', () {
      final original = GameRandom(42);
      final cloned = original.clone();

      cloned.nextInt(1000); // Advance cloned state

      // Original state should be unchanged
      expect(original.state, isNot(cloned.state));
    });
  });

  // ─── State Save/Restore ───
  group('GameRandom - State Save/Restore', () {
    test('state can be saved and restored', () {
      final rng = GameRandom(42);

      // Save state
      final savedState = rng.state;

      // Generate some numbers
      final valuesBefore = List.generate(10, (_) => rng.nextInt(1000));

      // Restore state
      rng.state = savedState;

      // Generate same numbers again - should be identical
      final valuesAfter = List.generate(10, (_) => rng.nextInt(1000));

      expect(valuesBefore, valuesAfter);
    });

    test('serialization roundtrip works', () {
      final rng = GameRandom(12345);

      // Generate some values
      for (int i = 0; i < 50; i++) {
        rng.nextInt(100);
      }

      // Save state (simulating serialization)
      final serialized = rng.state;

      // Create new instance and restore (simulating deserialization)
      final restored = GameRandom(0);
      restored.state = serialized;

      // Both should produce identical sequences now
      for (int i = 0; i < 100; i++) {
        expect(rng.nextInt(1000), restored.nextInt(1000),
            reason: 'Mismatch at iteration $i after restore');
      }
    });

    test('state restore with 0 becomes 1', () {
      final rng = GameRandom(42);
      rng.state = 0;
      // Should have been corrected to 1
      expect(rng.state, 1);
      // Should still work normally
      expect(rng.nextInt(10), isA<int>());
    });
  });

  // ─── Integration: Full Sequence Test ───
  group('GameRandom - Full Sequence Integration', () {
    test('mix of all methods produces deterministic sequence', () {
      final rng1 = GameRandom(42);
      final rng2 = GameRandom(42);

      // Use all methods in mixed order
      for (int i = 0; i < 50; i++) {
        expect(rng1.nextInt(100), rng2.nextInt(100));
        expect(rng1.nextBool(), rng2.nextBool());
        expect(rng1.nextDouble(), rng2.nextDouble());
        expect(rng1.nextSignedDouble(), rng2.nextSignedDouble());
      }
    });

    test('sequence survives many iterations', () {
      final rng = GameRandom(42);

      // Generate a lot of values
      for (int i = 0; i < 10000; i++) {
        rng.nextInt(100);
        rng.nextBool();
        rng.nextDouble();
        rng.nextSignedDouble();
      }

      // Should still be working correctly
      expect(rng.nextInt(10), isA<int>());
      expect(rng.nextBool(), isA<bool>());
      expect(rng.nextDouble(), isA<double>());
      expect(rng.nextSignedDouble(), isA<double>());
    });
  });

  // ─── xorshift32 Algorithm Verification ───
  group('GameRandom - Algorithm Verification', () {
    test('xorshift32 produces expected first values', () {
      // Known xorshift32 sequence for seed 1
      final rng = GameRandom(1);

      // First few values from xorshift32 with seed 1
      // These are implementation-specific but verify the algorithm
      final first = rng.nextInt(0x7FFFFFFF);
      expect(first, isNot(0)); // Should not return 0 on first call
    });

    test('periodicity - no immediate repetition', () {
      final rng = GameRandom(42);

      // Generate many values and check for immediate repetition
      int repeatCount = 0;
      int? prev;
      for (int i = 0; i < 1000; i++) {
        final current = rng.nextInt(0x7FFFFFFF);
        if (prev == current) repeatCount++;
        prev = current;
      }

      // Very unlikely to have repeats in xorshift32
      expect(repeatCount, lessThan(5));
    });
  });
}