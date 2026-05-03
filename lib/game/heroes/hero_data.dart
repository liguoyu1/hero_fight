import 'package:flutter/material.dart';

import '../components/hero_renderer.dart';
export '../components/hero_renderer.dart' show HeroVisuals, BodyType;

/// Faction enum for hero classification
enum Faction { threeKingdoms, mythology, warring }

/// Projectile hit effect types
enum OnHitEffect { none, freeze, stun }

/// Projectile behavior types
enum ProjectileType { normal, homing, bouncing, piercing }

/// Direction input for combo/directional attacks
enum AttackDirection { neutral, forward, backward, up, down }

/// Configuration for a projectile spawned by a skill
class ProjectileConfig {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double damage;
  final double lifetime;
  final Color color;
  final double width;
  final double height;
  final ProjectileType type;
  final OnHitEffect onHitEffect;
  final double effectDuration;

  const ProjectileConfig({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    this.lifetime = 2.0,
    this.color = Colors.white,
    this.width = 10,
    this.height = 10,
    this.type = ProjectileType.normal,
    this.onHitEffect = OnHitEffect.none,
    this.effectDuration = 0.0,
  });
}

/// Skill result: either projectiles, a direct effect, or both
class SkillResult {
  final List<ProjectileConfig> projectiles;
  final bool dashForward;
  final double dashDistance;
  final double dashDamage;
  final double knockback;
  final bool spinAttack;
  final double spinRadius;
  final double spinDamage;
  final double chargeTime;

  const SkillResult({
    this.projectiles = const [],
    this.dashForward = false,
    this.dashDistance = 0,
    this.dashDamage = 0,
    this.knockback = 0,
    this.spinAttack = false,
    this.spinRadius = 0,
    this.spinDamage = 0,
    this.chargeTime = 0,
  });
}

/// Directional attack definition — triggered by direction + attack key
class DirectionalAttack {
  final AttackDirection direction;
  final double damage;          // multiplier on base attackPower
  final double range;           // hitbox range
  final double hitboxHeight;    // hitbox height
  final double duration;        // attack animation duration
  final double knockbackX;
  final double knockbackY;
  final OnHitEffect onHitEffect;
  final double effectDuration;
  final String label;           // display name for debug

  const DirectionalAttack({
    required this.direction,
    this.damage = 1.0,
    this.range = 60,
    this.hitboxHeight = 70,
    this.duration = 0.3,
    this.knockbackX = 200,
    this.knockbackY = -100,
    this.onHitEffect = OnHitEffect.none,
    this.effectDuration = 0,
    this.label = '',
  });
}

/// Normal attack profile — each hero has unique feel
class NormalAttackProfile {
  /// Base damage multiplier (applied to hero's attackPower)
  final double damageMultiplier;
  /// Hitbox range in pixels
  final double range;
  /// Hitbox height (fraction of fighter height, 0.5–1.5)
  final double hitboxHeightRatio;
  /// Attack animation duration in seconds
  final double duration;
  /// Knockback on hit
  final double knockbackX;
  final double knockbackY;
  /// Forward lunge speed during attack
  final double lungeSpeed;
  /// Max combo hits before reset
  final int maxComboHits;
  /// Damage multiplier per combo hit (e.g. [1.0, 0.9, 1.2] for 3-hit combo)
  final List<double> comboMultipliers;

  const NormalAttackProfile({
    this.damageMultiplier = 1.0,
    this.range = 60,
    this.hitboxHeightRatio = 1.0,
    this.duration = 0.3,
    this.knockbackX = 200,
    this.knockbackY = -100,
    this.lungeSpeed = 80,
    this.maxComboHits = 1,
    this.comboMultipliers = const [1.0],
  });

  double getDamageForHit(int hitIndex, double basePower) {
    final idx = hitIndex.clamp(0, comboMultipliers.length - 1);
    return basePower * damageMultiplier * comboMultipliers[idx];
  }
}

/// Base class for all hero data definitions
abstract class HeroData {
  final String id;
  final String name;
  final String nameEn; // English name
  final String title;
  final String titleEn; // English title
  final Faction faction;
  final int colorValue;

  // Skill info
  final String skillName;
  final String skillNameEn; // English skill name
  final String skillDesc;
  final String skillDescEn; // English skill description

  // Stats
  final double hp;
  final double speed;
  final double jumpForce;
  final double attackPower;
  final double defense;
  final double skillCooldown;
  final double skillDamage;

  // Combat profile — unique per hero
  final NormalAttackProfile normalAttack;
  final List<DirectionalAttack> directionalAttacks;

  // Visual appearance
  final HeroVisuals visuals;

  const HeroData({
    required this.id,
    required this.name,
    this.nameEn = '',
    required this.title,
    this.titleEn = '',
    required this.faction,
    required this.colorValue,
    required this.skillName,
    this.skillNameEn = '',
    required this.skillDesc,
    this.skillDescEn = '',
    required this.hp,
    required this.speed,
    required this.jumpForce,
    required this.attackPower,
    required this.defense,
    required this.skillCooldown,
    required this.skillDamage,
    this.normalAttack = const NormalAttackProfile(),
    this.directionalAttacks = const [],
    this.visuals = const HeroVisuals(),
  });

  /// Get the Color object from the stored int value
  Color get color => Color(colorValue);

  /// Execute this hero's unique skill.
  SkillResult executeSkill({
    required double posX,
    required double posY,
    required bool facingRight,
  });

  /// Get directional attack for given direction (null = use normal attack)
  DirectionalAttack? getDirectionalAttack(AttackDirection dir) {
    for (final da in directionalAttacks) {
      if (da.direction == dir) return da;
    }
    return null;
  }
}
