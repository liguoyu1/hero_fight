import 'package:flame/components.dart';

import '../components/fighter.dart';
import '../components/projectile.dart' as pj;
import 'hero_data.dart';

/// Converts a [SkillResult] from a hero's skill definition into
/// actual [Projectile] game components, and applies dash/spin effects
/// directly to the [Fighter].
///
/// Returns the list of Projectiles to be added to the game world.
List<pj.Projectile> applySkillEffect(
  SkillResult result,
  Fighter owner,
) {
  final facingRight = owner.facingRight;
  final dir = facingRight ? 1.0 : -1.0;

  final projectiles = <pj.Projectile>[];

  // --- Projectiles ---
  for (final config in result.projectiles) {
    final speed = Vector2(config.vx, config.vy).length;
    final direction = speed > 0
        ? Vector2(config.vx, config.vy).normalized()
        : Vector2(dir, 0);

    // Determine the type enum
    pj.ProjectileType pType;
    switch (config.type) {
      case ProjectileType.normal:
        pType = pj.ProjectileType.normal;
      case ProjectileType.homing:
        pType = pj.ProjectileType.homing;
      case ProjectileType.bouncing:
        pType = pj.ProjectileType.bouncing;
      case ProjectileType.piercing:
        pType = pj.ProjectileType.piercing;
    }

    // Determine shape from width/height
    final aspect = config.width / config.height;
    final pShape = (aspect > 0.3 && aspect < 3.0)
        ? pj.ProjectileShape.circle
        : pj.ProjectileShape.rect;

    final proj = pj.Projectile(
      owner: owner,
      damage: config.damage,
      speed: speed,
      direction: direction,
      color: config.color,
      lifetime: config.lifetime,
      shape: pShape,
      type: pType,
      radius: (config.width + config.height) / 4,
      initialPosition: Vector2(config.x, config.y),
      bouncesLeft: 3,
      onHitEffect: config.onHitEffect,
      effectDuration: config.effectDuration,
    );

    projectiles.add(proj);
  }

  // --- Apply fighter effects ---
  if (result.dashForward) {
    owner.velocity.x = dir * result.dashDistance / 0.15;
  }

  return projectiles;
}
