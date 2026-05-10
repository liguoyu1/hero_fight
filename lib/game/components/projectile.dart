import 'dart:ui';

import 'package:flame/components.dart';

import 'fighter.dart';
import '../heroes/hero_data.dart' show OnHitEffect;
import '../audio/sound_manager.dart';

/// Projectile shape types
enum ProjectileShape { circle, rect, diamond }

/// Special projectile behaviors
enum ProjectileType { normal, homing, bouncing, piercing }

/// Projectile component fired by fighters
class Projectile extends PositionComponent {
  final Fighter owner;
  final double damage;
  final double speed;
  Vector2 direction;
  final Color color;
  double lifetime;
  final ProjectileShape shape;
  final ProjectileType type;
  final double radius;

  // Homing
  Fighter? homingTarget;
  double homingStrength;

  // Bouncing
  int bouncesLeft;

  // Piercing
  final Set<Fighter> _hitFighters = {};

  // On-hit effects (freeze, stun)
  final OnHitEffect onHitEffect;
  final double effectDuration;

  // Trail history for visual effect
  final List<Offset> _trail = [];
  static const int _maxTrailLength = 8;

  bool expired = false;

  // Game world boundaries (fixed 1280×600 world, matched to FighterGame)
  static const double worldLeft = 0;
  static const double worldRight = 1280;
  static const double worldGroundY = 600;
  static const double worldCeilingY = -50;

  Projectile({
    required this.owner,
    required this.damage,
    required this.speed,
    required this.direction,
    required this.color,
    this.lifetime = 3.0,
    this.shape = ProjectileShape.circle,
    this.type = ProjectileType.normal,
    this.radius = 8,
    this.homingTarget,
    this.homingStrength = 3.0,
    this.bouncesLeft = 3,
    this.onHitEffect = OnHitEffect.none,
    this.effectDuration = 0.0,
    Vector2? initialPosition,
  }) {
    size = Vector2(radius * 2, radius * 2);
    position = initialPosition ?? Vector2.zero();
    if (direction.length > 0) direction = direction.normalized();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (expired) return;

    lifetime -= dt;
    if (lifetime <= 0) {
      expired = true;
      return;
    }

    // Homing behavior
    if (type == ProjectileType.homing && homingTarget != null && homingTarget!.isAlive) {
      final toTarget = (homingTarget!.position + homingTarget!.size / 2) -
          (position + size / 2);
      if (toTarget.length > 0) {
        final desired = toTarget.normalized();
        direction = (direction + desired * homingStrength * dt).normalized();
      }
    }

    // Move
    position += direction * speed * dt;

    // Record trail
    _trail.add(Offset(position.x + radius, position.y + radius));
    if (_trail.length > _maxTrailLength) {
      _trail.removeAt(0);
    }

    // Boundary checks — destroy on exit (no wrap-around)
    final cx = position.x + radius;
    final cy = position.y + radius;

    if (type == ProjectileType.bouncing) {
      // Bouncing: reflect off edges within game-area bounds
      if (cx <= worldLeft || cx >= worldRight) {
        direction.x = -direction.x;
        if (cx <= worldLeft) {
          position.x = worldLeft;
        } else {
          position.x = worldRight - radius * 2;
        }
        bouncesLeft--;
      }
      if (cy <= worldCeilingY || cy >= worldGroundY) {
        direction.y = -direction.y;
        if (cy <= worldCeilingY) {
          position.y = worldCeilingY;
        } else {
          position.y = worldGroundY - radius * 2;
        }
        bouncesLeft--;
      }
      if (bouncesLeft <= 0) expired = true;
    } else {
      // Normal/homing/piercing: destroy when leaving game world
      final margin = radius * 2;
      if (cx < worldLeft - margin || cx > worldRight + margin ||
          cy < worldCeilingY - margin || cy > worldGroundY + margin) {
        expired = true;
      }
    }
  }

  /// Check collision with a fighter. Returns true if hit.
  bool checkHit(Fighter target) {
    if (expired || target == owner || !target.isAlive || target.isInvincible) return false;
    if (type == ProjectileType.piercing && _hitFighters.contains(target)) return false;

    final projCenter = position + Vector2(radius, radius);
    final targetRect = Rect.fromLTWH(
      target.position.x, target.position.y,
      Fighter.fighterWidth, Fighter.fighterHeight,
    );
    // Simple circle-rect collision
    final closestX = projCenter.x.clamp(targetRect.left, targetRect.right);
    final closestY = projCenter.y.clamp(targetRect.top, targetRect.bottom);
    final dist = (projCenter - Vector2(closestX, closestY)).length;

    if (dist <= radius) {
      final knockback = Vector2(direction.x * 150, -80);
      target.takeDamage(damage, knockback);

      // Apply on-hit effects
      if (onHitEffect == OnHitEffect.freeze && target.isAlive) {
        target.applyFreeze(effectDuration);
        SoundManager().playFreeze();
      } else if (onHitEffect == OnHitEffect.stun && target.isAlive) {
        target.applyStun(effectDuration);
        SoundManager().playStun();
      }

      if (type == ProjectileType.piercing) {
        _hitFighters.add(target);
      } else {
        expired = true;
      }
      return true;
    }
    return false;
  }

  // Cached Paint objects — reused every frame to avoid GC pressure
  final Paint _paint = Paint();
  final Paint _glowPaint = Paint();
  final Paint _trailPaint = Paint();
  final Paint _highlightPaint = Paint()..color = const Color(0x66FFFFFF);
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (expired) return;

    // Render culling: skip if projectile is outside stage bounds (1280×600)
    final margin = radius * 3;
    if (position.x + size.x < -margin || position.x > 1280 + margin ||
        position.y + size.y < -margin || position.y > 600 + margin) {
      return;
    }

    _paint.color = color;
    // Glow without MaskFilter.blur (GPU-heavy on mobile) — use alpha + larger radius instead
    _glowPaint.color = color.withValues(alpha: 0.15);

    // Trail
    for (int i = 0; i < _trail.length; i++) {
      final alpha = (i / _trail.length) * 0.4;
      final trailSize = radius * (0.3 + 0.5 * i / _trail.length);
      _trailPaint.color = color.withValues(alpha: alpha);
      final localX = _trail[i].dx - position.x;
      final localY = _trail[i].dy - position.y;
      canvas.drawCircle(Offset(localX, localY), trailSize, _trailPaint);
    }

    // Glow (soft outer ring to replace blur)
    canvas.drawCircle(Offset(radius, radius), radius + 4, _glowPaint);

    switch (shape) {
      case ProjectileShape.circle:
        canvas.drawCircle(Offset(radius, radius), radius, _paint);
        // Inner highlight
        canvas.drawCircle(Offset(radius - 2, radius - 2), radius * 0.4, _highlightPaint);
        // Outer ring
        _ringPaint.color = color.withValues(alpha: 0.5);
        canvas.drawCircle(Offset(radius, radius), radius + 1, _ringPaint);
        break;
      case ProjectileShape.rect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, radius * 2, radius * 2),
            const Radius.circular(3),
          ),
          _paint,
        );
        break;
      case ProjectileShape.diamond:
        final path = Path()
          ..moveTo(radius, 0)
          ..lineTo(radius * 2, radius)
          ..lineTo(radius, radius * 2)
          ..lineTo(0, radius)
          ..close();
        canvas.drawPath(path, _paint);
        break;
    }
  }

  /// Full serialization — captures all mutable state at a given frame.
  /// Fighter references are encoded as playerIndex for portability.
  Map<String, dynamic> toJson() => {
        'ownerPlayerIndex': owner.playerIndex,
        'damage': damage,
        'speed': speed,
        'px': position.x,
        'py': position.y,
        'vx': direction.x,
        'vy': direction.y,
        'color': color.toARGB32(),
        'lifetime': lifetime,
        'shape': shape.index,
        'type': type.index,
        'radius': radius,
        'homingTargetPlayerIndex': homingTarget?.playerIndex,
        'homingStrength': homingStrength,
        'bouncesLeft': bouncesLeft,
        'hitFighterPlayerIndices':
            _hitFighters.map((f) => f.playerIndex).toList(),
        'onHitEffect': onHitEffect.index,
        'effectDuration': effectDuration,
        'expired': expired,
      };

  /// Reconstruct a projectile from serialized state.
  /// [fightersByPlayerIndex] maps playerIndex → Fighter for resolving references.
  static Projectile fromJson(
    Map<String, dynamic> json,
    Map<int, Fighter> fightersByPlayerIndex,
  ) {
    final owner = fightersByPlayerIndex[json['ownerPlayerIndex']]!;
    final targetIdx = json['homingTargetPlayerIndex'] as int?;
    final proj = Projectile(
      owner: owner,
      damage: (json['damage'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      direction: Vector2(
        (json['vx'] as num).toDouble(),
        (json['vy'] as num).toDouble(),
      ),
      color: Color(json['color'] as int),
      lifetime: (json['lifetime'] as num).toDouble(),
      shape: ProjectileShape.values[json['shape'] as int],
      type: ProjectileType.values[json['type'] as int],
      radius: (json['radius'] as num).toDouble(),
      homingTarget:
          targetIdx != null ? fightersByPlayerIndex[targetIdx] : null,
      homingStrength: (json['homingStrength'] as num).toDouble(),
      bouncesLeft: (json['bouncesLeft'] as num).toInt(),
      onHitEffect: OnHitEffect.values[json['onHitEffect'] as int],
      effectDuration: (json['effectDuration'] as num).toDouble(),
      initialPosition: Vector2(
        (json['px'] as num).toDouble(),
        (json['py'] as num).toDouble(),
      ),
    );
    proj.expired = json['expired'] as bool;
    // Restore pierced fighters for piercing type
    final hitIndices = json['hitFighterPlayerIndices'] as List<dynamic>?;
    if (hitIndices != null) {
      for (final idx in hitIndices) {
        proj._hitFighters.add(fightersByPlayerIndex[idx as int]!);
      }
    }
    return proj;
  }
}
