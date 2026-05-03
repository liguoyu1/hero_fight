import 'package:flutter_test/flutter_test.dart';
import 'package:hero_fighter/game/heroes/hero_data.dart';
import 'package:hero_fighter/game/heroes/lubu.dart';
import 'package:hero_fighter/game/heroes/zhuge.dart';

void main() {
  group('Combat System - Damage Calculation', () {
    test('Base attack damage calculation', () {
      final lubu = LubuHero();
      expect(lubu.attackPower, 52.0);
      expect(lubu.normalAttack.damageMultiplier, 1.0);
      
      final actualDamage = lubu.attackPower * lubu.normalAttack.damageMultiplier;
      expect(actualDamage, 52.0);
    });

    test('Directional attack damage multipliers', () {
      final lubu = LubuHero();
      final upAttack = lubu.directionalAttacks
          .firstWhere((a) => a.direction == AttackDirection.up);
      
      expect(upAttack.damage, 1.2);
      expect(lubu.attackPower * upAttack.damage, 62.4);
    });

    test('Skill damage calculation', () {
      final zhuge = ZhugeHero();
      expect(zhuge.skillDamage, 80.0);
    });

    test('Defense reduces damage correctly', () {
      final lubu = LubuHero();
      final zhuge = ZhugeHero();
      
      final rawDamage = lubu.attackPower;
      final reducedDamage = rawDamage * (1 - zhuge.defense / 100);
      
      expect(reducedDamage, lessThan(rawDamage));
      expect(reducedDamage, closeTo(52.0 * (1 - 18.0 / 100), 0.1));
    });
  });

  group('Combat System - Collision Detection', () {
    test('Attack range validation', () {
      final lubu = LubuHero();
      expect(lubu.normalAttack.range, 80.0);
    });

    test('Directional attack ranges', () {
      final lubu = LubuHero();
      
      final forwardAttack = lubu.directionalAttacks
          .firstWhere((a) => a.direction == AttackDirection.forward);
      expect(forwardAttack.range, greaterThan(lubu.normalAttack.range));
      
      final upAttack = lubu.directionalAttacks
          .firstWhere((a) => a.direction == AttackDirection.up);
      expect(upAttack.hitboxHeight, greaterThan(0));
    });
  });

  group('Combat System - Knockback', () {
    test('Normal attack knockback', () {
      final lubu = LubuHero();
      expect(lubu.normalAttack.knockbackX, 250.0);
      expect(lubu.normalAttack.knockbackY, -80.0);
    });

    test('Directional attack knockback variations', () {
      final lubu = LubuHero();
      
      final forwardAttack = lubu.directionalAttacks
          .firstWhere((a) => a.direction == AttackDirection.forward);
      expect(forwardAttack.knockbackX, greaterThan(lubu.normalAttack.knockbackX));
    });
  });

  group('Combat System - Combo System', () {
    test('Combo chain configuration', () {
      final lubu = LubuHero();
      expect(lubu.normalAttack.maxComboHits, 3);
      expect(lubu.normalAttack.comboMultipliers.length, 3);
    });

    test('Combo damage progression', () {
      final lubu = LubuHero();
      final comboDamages = lubu.normalAttack.comboMultipliers;
      
      expect(comboDamages.length, 3);
      expect(comboDamages[2], greaterThan(comboDamages[0])); // Final hit stronger
    });
  });

  group('Combat System - Hero Stats Balance', () {
    test('All heroes have valid base stats', () {
      final heroes = [LubuHero(), ZhugeHero()];
      
      for (final hero in heroes) {
        expect(hero.hp, greaterThan(0));
        expect(hero.attackPower, greaterThan(0));
        expect(hero.defense, greaterThanOrEqualTo(0));
        expect(hero.speed, greaterThan(0));
        expect(hero.jumpForce, greaterThan(0));
      }
    });

    test('Hero stat diversity', () {
      final lubu = LubuHero();
      final zhuge = ZhugeHero();
      
      // Lubu should be tankier
      expect(lubu.hp, greaterThan(zhuge.hp));
      expect(lubu.defense, greaterThan(zhuge.defense));
      
      // Zhuge should be faster
      expect(zhuge.speed, greaterThan(lubu.speed));
    });
  });
}
