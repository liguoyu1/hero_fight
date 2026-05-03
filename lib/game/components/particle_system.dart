import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../utils/game_random.dart';

/// A single particle with position, velocity, color, and lifetime.
/// Pooled — reused via [reset] instead of being created/destroyed.
class _Particle {
  double x = 0, y = 0, vx = 0, vy = 0;
  double life = 0, maxLife = 1;
  double size = 3;
  Color color = const Color(0xFFFFFFFF);
  double gravity = 0;
  double friction = 1;
  bool active = false;

  _Particle();

  bool get isDead => life <= 0;
  double get alpha => (life / maxLife).clamp(0, 1);

  void reset({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
    required Color color,
    double size = 3,
    double gravity = 0,
    double friction = 1,
  }) {
    this.x = x;
    this.y = y;
    this.vx = vx;
    this.vy = vy;
    this.life = life;
    maxLife = life;
    this.color = color;
    this.size = size;
    this.gravity = gravity;
    this.friction = friction;
    active = true;
  }

  void update(double dt) {
    life -= dt;
    x += vx * dt;
    y += vy * dt;
    vy += gravity * dt;
    vx *= pow(friction, dt).toDouble();
    vy *= pow(friction, dt).toDouble();
    if (isDead) active = false;
  }
}

/// Lightweight particle system with object pooling for visual effects.
///
/// Pre-allocates particles and reuses them to avoid GC pressure during combat.
class ParticleSystem extends PositionComponent {
  final List<_Particle> _pool = [];
  int _activeCount = 0;
  final GameRandom _rng;

  /// Initial pool size — covers a typical combat burst
  static const int _initialPoolSize = 64;

  /// Number of currently active particles
  int get activeCount => _activeCount;

  /// Total pool size (active + inactive)
  int get poolSize => _pool.length;

  ParticleSystem({GameRandom? rng}) : _rng = rng ?? GameRandom() {
    priority = 90; // Above fighters, below HUD
    // Pre-allocate pool
    for (int i = 0; i < _initialPoolSize; i++) {
      _pool.add(_Particle());
    }
  }

  /// Acquire a particle from the pool. Grows pool if all are active.
  _Particle _acquire({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
    required Color color,
    double size = 3,
    double gravity = 0,
    double friction = 1,
  }) {
    // Find first inactive particle
    for (final p in _pool) {
      if (!p.active) {
        p.reset(
          x: x, y: y, vx: vx, vy: vy,
          life: life, color: color,
          size: size, gravity: gravity, friction: friction,
        );
        _activeCount++;
        return p;
      }
    }
    // Pool exhausted — grow by one
    final p = _Particle();
    p.reset(
      x: x, y: y, vx: vx, vy: vy,
      life: life, color: color,
      size: size, gravity: gravity, friction: friction,
    );
    _pool.add(p);
    _activeCount++;
    return p;
  }

  /// Spawn hit sparks at a position
  void spawnHitSparks(double x, double y, Color color, {int count = 8}) {
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 80 + _rng.nextDouble() * 200;
      _acquire(
        x: x, y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 50,
        life: 0.2 + _rng.nextDouble() * 0.3,
        color: _randomize(color),
        size: 2 + _rng.nextDouble() * 3,
        gravity: 300,
        friction: 0.95,
      );
    }
  }

  /// Spawn attack trail particles (motion blur)
  void spawnAttackTrail(double x, double y, bool facingRight, Color color) {
    final dir = facingRight ? 1.0 : -1.0;
    for (int i = 0; i < 5; i++) {
      _acquire(
        x: x + _rng.nextDouble() * 30 * dir,
        y: y - 10 + _rng.nextDouble() * 40,
        vx: dir * (40 + _rng.nextDouble() * 60),
        vy: -20 + _rng.nextDouble() * 40,
        life: 0.15 + _rng.nextDouble() * 0.15,
        color: color.withValues(alpha: 0.6),
        size: 4 + _rng.nextDouble() * 6,
        friction: 0.9,
      );
    }
  }

  /// Spawn skill activation burst
  void spawnSkillBurst(double x, double y, Color color, {int count = 15}) {
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 50 + _rng.nextDouble() * 150;
      _acquire(
        x: x, y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        life: 0.3 + _rng.nextDouble() * 0.5,
        color: _randomize(color),
        size: 3 + _rng.nextDouble() * 5,
        gravity: -50,
        friction: 0.92,
      );
    }
  }

  /// Spawn element-specific particles (fire, ice, lightning)
  void spawnElementTrail(double x, double y, Color color, String element) {
    switch (element) {
      case 'fire':
        for (int i = 0; i < 4; i++) {
          _acquire(
            x: x + _rng.nextDouble() * 10 - 5,
            y: y + _rng.nextDouble() * 10 - 5,
            vx: _rng.nextDouble() * 30 - 15,
            vy: -40 - _rng.nextDouble() * 60,
            life: 0.2 + _rng.nextDouble() * 0.3,
            color: Color.lerp(const Color(0xFFFF4400), const Color(0xFFFFCC00),
                _rng.nextDouble())!,
            size: 3 + _rng.nextDouble() * 4,
            gravity: -100,
          );
        }
        break;
      case 'ice':
        for (int i = 0; i < 3; i++) {
          _acquire(
            x: x + _rng.nextDouble() * 16 - 8,
            y: y + _rng.nextDouble() * 16 - 8,
            vx: _rng.nextDouble() * 20 - 10,
            vy: -10 - _rng.nextDouble() * 20,
            life: 0.4 + _rng.nextDouble() * 0.4,
            color: Color.lerp(const Color(0xFF88DDFF), const Color(0xFFFFFFFF),
                _rng.nextDouble())!,
            size: 2 + _rng.nextDouble() * 3,
            gravity: -20,
          );
        }
        break;
      case 'lightning':
        for (int i = 0; i < 3; i++) {
          _acquire(
            x: x + _rng.nextDouble() * 20 - 10,
            y: y + _rng.nextDouble() * 20 - 10,
            vx: _rng.nextDouble() * 200 - 100,
            vy: _rng.nextDouble() * 200 - 100,
            life: 0.05 + _rng.nextDouble() * 0.1,
            color: const Color(0xFFFFFF88),
            size: 1.5 + _rng.nextDouble() * 2,
          );
        }
        break;
    }
  }

  /// Spawn dust puff (landing, dash)
  void spawnDust(double x, double y, {int count = 6}) {
    for (int i = 0; i < count; i++) {
      final angle = -pi * 0.2 - _rng.nextDouble() * pi * 0.6;
      final speed = 30 + _rng.nextDouble() * 50;
      _acquire(
        x: x + _rng.nextDouble() * 20 - 10,
        y: y,
        vx: cos(angle) * speed * (_rng.nextBool() ? 1 : -1),
        vy: sin(angle) * speed,
        life: 0.3 + _rng.nextDouble() * 0.3,
        color: const Color(0x88BBAA88),
        size: 4 + _rng.nextDouble() * 4,
        gravity: 50,
        friction: 0.9,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _activeCount = 0;
    for (final p in _pool) {
      if (p.active) {
        p.update(dt);
        if (p.active) _activeCount++;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final p in _pool) {
      if (!p.active) continue;
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.alpha * p.color.a);
      final currentSize = p.size * (0.5 + p.alpha * 0.5);
      canvas.drawCircle(Offset(p.x, p.y), currentSize, paint);
    }
  }

  Color _randomize(Color c) {
    final r = (c.r * 255 + _rng.nextInt(40) - 20).round().clamp(0, 255);
    final g = (c.g * 255 + _rng.nextInt(40) - 20).round().clamp(0, 255);
    final b = (c.b * 255 + _rng.nextInt(40) - 20).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }
}
