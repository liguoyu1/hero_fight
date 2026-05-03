import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../utils/game_random.dart';

/// Floating damage number that rises and fades out.
class DamageNumber extends PositionComponent {
  final double damage;
  final Color color;
  final double _startY;
  double _life = 0;
  static const double _duration = 0.8;
  static const double _floatDistance = 60;

  DamageNumber({
    required this.damage,
    required this.color,
    required Vector2 position,
  }) : _startY = position.y {
    this.position = position.clone();
    size = Vector2(80, 30);
    priority = 100; // Always on top
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position.y = _startY - (_life / _duration) * _floatDistance;
    if (_life >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final alpha = (1.0 - (_life / _duration)).clamp(0.0, 1.0);
    final scale = 1.0 + (_life / _duration) * 0.3;

    final text = damage.toStringAsFixed(0);
    final fontSize = 22 * scale;
    final c = color.withValues(alpha: alpha);

    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: fontSize,
    ))
      ..pushStyle(TextStyle(
        color: c,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Color(0xCC000000), blurRadius: 4),
        ],
      ))
      ..addText(text);
    final paragraph = builder.build();
    paragraph.layout(const ParagraphConstraints(width: 100));
    canvas.drawParagraph(
      paragraph,
      Offset(-paragraph.width / 2, 0),
    );
  }
}

/// Screen shake effect manager.
class ScreenShake {
  double _trauma = 0;
  final double _maxShake = 10;
  Vector2 currentOffset = Vector2.zero();
  GameRandom? _rng;

  /// Add shake intensity (0.0 to 1.0).
  void addTrauma(double amount) {
    _trauma = (_trauma + amount).clamp(0.0, 1.0);
  }

  /// Update the shake offset. Call each frame.
  void update(double dt, {double decay = 3.0}) {
    _trauma = max(0, _trauma - decay * dt);
    if (_trauma <= 0) {
      currentOffset = Vector2.zero();
      return;
    }
    final shake = _maxShake * _trauma * _trauma; // Square for sharp shake
    // Use injected GameRandom for determinism; fall back to Random() if not set
    final rng = _rng;
    if (rng != null) {
      currentOffset = Vector2(
        (rng.nextDouble() - 0.5) * 2 * shake,
        (rng.nextDouble() - 0.5) * 2 * shake,
      );
    } else {
      currentOffset = Vector2(
        (Random().nextDouble() - 0.5) * 2 * shake,
        (Random().nextDouble() - 0.5) * 2 * shake,
      );
    }
  }

  bool get isShaking => _trauma > 0;

  /// Inject a deterministic PRNG for rollback compatibility.
  set random(GameRandom rng) => _rng = rng;
}

/// Brief flash overlay for hit reaction.
class HitFlash extends PositionComponent {
  final Color color;
  double _life = 0;
  static const double _duration = 0.12;

  HitFlash({
    required Vector2 size,
    this.color = const Color(0x44FFFFFF),
  }) {
    this.size = size;
    priority = 50;
  }

  void trigger() {
    _life = _duration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_life > 0) {
      _life -= dt;
      if (_life <= 0) _life = 0;
    }
  }

  bool get isActive => _life > 0;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!isActive) return;
    final alpha = (_life / _duration).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: alpha * 0.3);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}
