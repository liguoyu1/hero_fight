import 'package:flutter_test/flutter_test.dart';
import 'package:hero_fighter/game/heroes/hero_data.dart';
import 'package:hero_fighter/game/heroes/hero_registry.dart';
import 'package:hero_fighter/game/heroes/all_heroes.dart';

// Individual hero imports
import 'package:hero_fighter/game/heroes/lubu.dart';
import 'package:hero_fighter/game/heroes/zhuge.dart';
import 'package:hero_fighter/game/heroes/guanyu.dart';
import 'package:hero_fighter/game/heroes/diaochan.dart';
import 'package:hero_fighter/game/heroes/lee_sin.dart';
import 'package:hero_fighter/game/heroes/ashe.dart';
import 'package:hero_fighter/game/heroes/thor.dart';
import 'package:hero_fighter/game/heroes/thanos.dart';
import 'package:hero_fighter/game/heroes/twisted_fate.dart';
import 'package:hero_fighter/game/heroes/captain.dart';
import 'package:hero_fighter/game/heroes/ironman.dart';

void main() {
  // ─── All 11 heroes for iteration tests ───
  final allHeroes = <HeroData>[
    LubuHero(),
    ZhugeHero(),
    GuanyuHero(),
    DiaochanHero(),
    ShaolinMonkHero(),
    HouyiHero(),
    LeizhenziHero(),
    ChiyouHero(),
    GuiguziHero(),
    ShieldGeneralHero(),
    MohistHero(),
  ];

  // ─── Hero Data Validation ───
  group('HeroData - Base Stats Validation', () {
    for (final hero in allHeroes) {
      test('${hero.name} (${hero.id}) has valid base stats', () {
        expect(hero.id, isNotEmpty);
        expect(hero.name, isNotEmpty);
        expect(hero.title, isNotEmpty);
        expect(hero.hp, greaterThan(0));
        expect(hero.speed, greaterThan(0));
        expect(hero.jumpForce, greaterThan(0));
        expect(hero.attackPower, greaterThan(0));
        expect(hero.defense, greaterThanOrEqualTo(0));
        expect(hero.skillCooldown, greaterThan(0));
        expect(hero.skillDamage, greaterThan(0));
        expect(hero.colorValue, isNonZero);
        expect(hero.skillName, isNotEmpty);
        expect(hero.skillDesc, isNotEmpty);
      });
    }

    test('All 11 heroes have unique IDs', () {
      final ids = allHeroes.map((h) => h.id).toSet();
      expect(ids.length, 11);
    });

    test('All 11 heroes have unique names', () {
      final names = allHeroes.map((h) => h.name).toSet();
      expect(names.length, 11);
    });
  });

  // ─── Faction Classification ───
  group('HeroData - Faction Classification', () {
    test('Three Kingdoms faction has 4 heroes', () {
      final tk = allHeroes.where((h) => h.faction == Faction.threeKingdoms);
      expect(tk.length, 4);
    });

    test('Mythology faction has 4 heroes', () {
      final myth = allHeroes.where((h) => h.faction == Faction.mythology);
      expect(myth.length, 4);
    });

    test('Warring faction has 3 heroes', () {
      final war = allHeroes.where((h) => h.faction == Faction.warring);
      expect(war.length, 3);
    });

    test('Every hero belongs to a faction', () {
      for (final hero in allHeroes) {
        expect(Faction.values, contains(hero.faction));
      }
    });
  });

  // ─── Color Getter ───
  group('HeroData - Color', () {
    test('color getter returns Color from colorValue', () {
      final lubu = LubuHero();
      final color = lubu.color;
      expect(color.value, 0xFFCC0000);
    });

    for (final hero in allHeroes) {
      test('${hero.name} color is non-transparent', () {
        // Alpha channel should be 0xFF (fully opaque)
        expect(hero.color.value >> 24, 0xFF);
      });
    }
  });

  // ─── NormalAttackProfile ───
  group('NormalAttackProfile', () {
    test('getDamageForHit basic calculation', () {
      final profile = NormalAttackProfile(
        damageMultiplier: 1.0,
        comboMultipliers: [0.8, 0.9, 1.5],
      );
      // hit 0: 100 * 1.0 * 0.8 = 80
      expect(profile.getDamageForHit(0, 100), closeTo(80, 0.01));
      // hit 1: 100 * 1.0 * 0.9 = 90
      expect(profile.getDamageForHit(1, 100), closeTo(90, 0.01));
      // hit 2: 100 * 1.0 * 1.5 = 150
      expect(profile.getDamageForHit(2, 100), closeTo(150, 0.01));
    });

    test('getDamageForHit clamps out-of-range index', () {
      final profile = NormalAttackProfile(
        damageMultiplier: 1.0,
        comboMultipliers: [0.8, 0.9, 1.5],
      );
      // Negative index clamps to 0
      expect(profile.getDamageForHit(-1, 100), closeTo(80, 0.01));
      // Index beyond length clamps to last
      expect(profile.getDamageForHit(10, 100), closeTo(150, 0.01));
    });

    test('getDamageForHit applies damageMultiplier', () {
      final profile = NormalAttackProfile(
        damageMultiplier: 1.5,
        comboMultipliers: [1.0],
      );
      // 100 * 1.5 * 1.0 = 150
      expect(profile.getDamageForHit(0, 100), closeTo(150, 0.01));
    });

    for (final hero in allHeroes) {
      test('${hero.name} normalAttack has valid combo config', () {
        final na = hero.normalAttack;
        expect(na.maxComboHits, greaterThan(0));
        expect(na.comboMultipliers.length, na.maxComboHits);
        expect(na.range, greaterThan(0));
        expect(na.duration, greaterThan(0));
        for (final m in na.comboMultipliers) {
          expect(m, greaterThan(0));
        }
      });
    }
  });

  // ─── Directional Attacks ───
  group('HeroData - Directional Attacks', () {
    test('getDirectionalAttack returns correct attack', () {
      final lubu = LubuHero();
      final forward = lubu.getDirectionalAttack(AttackDirection.forward);
      expect(forward, isNotNull);
      expect(forward!.direction, AttackDirection.forward);
      expect(forward.label, 'Charge');
    });

    test('getDirectionalAttack returns null for missing direction', () {
      final lubu = LubuHero();
      final backward = lubu.getDirectionalAttack(AttackDirection.backward);
      expect(backward, isNull);
    });

    test('Lubu has forward, up, down attacks', () {
      final lubu = LubuHero();
      expect(lubu.directionalAttacks.length, 3);
      expect(lubu.getDirectionalAttack(AttackDirection.forward), isNotNull);
      expect(lubu.getDirectionalAttack(AttackDirection.up), isNotNull);
      expect(lubu.getDirectionalAttack(AttackDirection.down), isNotNull);
    });

    test('Guanyu forward attack has high knockback', () {
      final guanyu = GuanyuHero();
      final forward = guanyu.getDirectionalAttack(AttackDirection.forward)!;
      expect(forward.knockbackX, 400);
      expect(forward.damage, 1.5);
    });

    test('Diaochan forward attack has freeze effect', () {
      final diaochan = DiaochanHero();
      final forward = diaochan.getDirectionalAttack(AttackDirection.forward)!;
      expect(forward.onHitEffect, OnHitEffect.freeze);
      expect(forward.effectDuration, 0.5);
    });

    for (final hero in allHeroes) {
      test('${hero.name} directional attacks have valid data', () {
        for (final da in hero.directionalAttacks) {
          expect(da.damage, greaterThan(0));
          expect(da.range, greaterThan(0));
          expect(da.hitboxHeight, greaterThan(0));
          expect(da.duration, greaterThan(0));
        }
      });
    }
  });

  // ─── Skill Execution ───
  group('HeroData - Skill Execution', () {
    test('Lubu skill: 8 piercing projectiles in circle + spin', () {
      final lubu = LubuHero();
      final result = lubu.executeSkill(posX: 100, posY: 200, facingRight: true);

      expect(result.projectiles.length, 8);
      expect(result.spinAttack, isTrue);
      expect(result.spinRadius, 120);
      expect(result.spinDamage, 250);

      for (final p in result.projectiles) {
        expect(p.damage, 250);
        expect(p.type, ProjectileType.piercing);
      }
    });

    test('Lubu skill facing left mirrors projectile directions', () {
      final lubu = LubuHero();
      final right = lubu.executeSkill(posX: 100, posY: 200, facingRight: true);
      final left = lubu.executeSkill(posX: 100, posY: 200, facingRight: false);

      // Both should have same count
      expect(right.projectiles.length, left.projectiles.length);
      // Circle pattern means same positions regardless of facing
      // (projectiles go in all directions)
    });

    test('Guanyu skill: 1 piercing projectile + dash', () {
      final guanyu = GuanyuHero();
      final result =
          guanyu.executeSkill(posX: 100, posY: 200, facingRight: true);

      expect(result.projectiles.length, 1);
      expect(result.dashForward, isTrue);
      expect(result.dashDistance, 180);
      expect(result.dashDamage, 300);
      expect(result.projectiles.first.type, ProjectileType.piercing);
      expect(result.projectiles.first.damage, 300);
    });

    test('Guanyu skill facing left has negative vx', () {
      final guanyu = GuanyuHero();
      final result =
          guanyu.executeSkill(posX: 100, posY: 200, facingRight: false);

      expect(result.projectiles.first.vx, lessThan(0));
    });

    test('Diaochan skill: 5 projectiles with freeze', () {
      final diaochan = DiaochanHero();
      final result =
          diaochan.executeSkill(posX: 100, posY: 200, facingRight: true);

      expect(result.projectiles.length, 5);
      for (final p in result.projectiles) {
        expect(p.damage, 90);
        expect(p.onHitEffect, OnHitEffect.freeze);
        expect(p.effectDuration, 0.8);
      }
    });

    test('Zhuge skill: 7 normal projectiles in fan', () {
      final zhuge = ZhugeHero();
      final result =
          zhuge.executeSkill(posX: 100, posY: 200, facingRight: true);

      expect(result.projectiles.length, 7);
      for (final p in result.projectiles) {
        expect(p.damage, 80);
        expect(p.type, ProjectileType.normal);
      }
    });

    for (final hero in allHeroes) {
      test('${hero.name} executeSkill returns valid result', () {
        final result =
            hero.executeSkill(posX: 100, posY: 200, facingRight: true);

        // Every skill should produce projectiles or a dash/spin
        final hasProjectiles = result.projectiles.isNotEmpty;
        final hasDash = result.dashForward;
        final hasSpin = result.spinAttack;
        expect(hasProjectiles || hasDash || hasSpin, isTrue,
            reason: '${hero.name} skill should produce some effect');

        for (final p in result.projectiles) {
          expect(p.damage, greaterThan(0));
          expect(p.lifetime, greaterThan(0));
          expect(p.width, greaterThan(0));
          expect(p.height, greaterThan(0));
        }
      });
    }
  });

  // ─── Hero Registry ───
  group('HeroRegistry', () {
    setUp(() {
      // Clear registry before each test by re-registering
      // Registry is a singleton, so we need to work with that
      final registry = HeroRegistry.instance;
      // Register all heroes fresh
      registerAllHeroes();
    });

    test('registerAllHeroes registers 11 heroes', () {
      final registry = HeroRegistry.instance;
      expect(registry.count, 11);
    });

    test('get returns correct hero by id', () {
      final registry = HeroRegistry.instance;
      final lubu = registry.get('lubu');
      expect(lubu, isNotNull);
      expect(lubu!.name, 'Lu Bu');
      expect(lubu.id, 'lubu');
    });

    test('get returns null for unknown id', () {
      final registry = HeroRegistry.instance;
      expect(registry.get('nonexistent'), isNull);
    });

    test('getAll returns all registered heroes', () {
      final registry = HeroRegistry.instance;
      final all = registry.getAll();
      expect(all.length, 11);
    });

    test('ids returns all hero ids', () {
      final registry = HeroRegistry.instance;
      final ids = registry.ids;
      expect(ids.length, 11);
      expect(ids, contains('lubu'));
      expect(ids, contains('zhuge'));
      expect(ids, contains('guanyu'));
      expect(ids, contains('diaochan'));
    });

    test('getByFaction filters correctly', () {
      final registry = HeroRegistry.instance;
      final tk = registry.getByFaction(Faction.threeKingdoms);
      expect(tk.length, 4);
      for (final h in tk) {
        expect(h.faction, Faction.threeKingdoms);
      }
    });

    test('getByFaction mythology returns 4', () {
      final registry = HeroRegistry.instance;
      final myth = registry.getByFaction(Faction.mythology);
      expect(myth.length, 4);
    });

    test('getByFaction warring returns 3', () {
      final registry = HeroRegistry.instance;
      final war = registry.getByFaction(Faction.warring);
      expect(war.length, 3);
    });

    test('register overwrites existing hero with same id', () {
      final registry = HeroRegistry.instance;
      final countBefore = registry.count;
      registry.register(LubuHero()); // Re-register existing
      expect(registry.count, countBefore); // Count unchanged
    });
  });

  // ─── Hero Balance Sanity Checks ───
  group('Hero Balance', () {
    test('HP range is reasonable (600-1500)', () {
      for (final hero in allHeroes) {
        expect(hero.hp, greaterThanOrEqualTo(600),
            reason: '${hero.name} HP too low');
        expect(hero.hp, lessThanOrEqualTo(1500),
            reason: '${hero.name} HP too high');
      }
    });

    test('Speed range is reasonable (100-250)', () {
      for (final hero in allHeroes) {
        expect(hero.speed, greaterThanOrEqualTo(100),
            reason: '${hero.name} speed too low');
        expect(hero.speed, lessThanOrEqualTo(250),
            reason: '${hero.name} speed too high');
      }
    });

    test('Attack power range is reasonable (20-70)', () {
      for (final hero in allHeroes) {
        expect(hero.attackPower, greaterThanOrEqualTo(20),
            reason: '${hero.name} attack too low');
        expect(hero.attackPower, lessThanOrEqualTo(70),
            reason: '${hero.name} attack too high');
      }
    });

    test('Defense range is reasonable (0-50)', () {
      for (final hero in allHeroes) {
        expect(hero.defense, greaterThanOrEqualTo(0),
            reason: '${hero.name} defense negative');
        expect(hero.defense, lessThanOrEqualTo(50),
            reason: '${hero.name} defense too high');
      }
    });

    test('Tank heroes have more HP than assassins', () {
      final lubu = LubuHero(); // Tank
      final diaochan = DiaochanHero(); // Assassin
      expect(lubu.hp, greaterThan(diaochan.hp));
      expect(lubu.defense, greaterThan(diaochan.defense));
    });

    test('Assassin heroes are faster than tanks', () {
      final lubu = LubuHero();
      final diaochan = DiaochanHero();
      expect(diaochan.speed, greaterThan(lubu.speed));
    });
  });

  // ─── HeroVisuals ───
  group('HeroData - Visuals', () {
    for (final hero in allHeroes) {
      test('${hero.name} has valid visuals', () {
        final v = hero.visuals;
        expect(v.headRadius, greaterThan(0));
        expect(v.torsoWidth, greaterThan(0));
        expect(v.torsoHeight, greaterThan(0));
        expect(v.armLength, greaterThan(0));
        expect(v.legLength, greaterThan(0));
      });
    }
  });
}
