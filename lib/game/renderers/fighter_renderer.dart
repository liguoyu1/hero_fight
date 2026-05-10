import 'dart:math';
import 'dart:ui';

import '../components/fighter.dart' show Fighter, FighterState, SkillVisualType;
import '../components/hero_renderer.dart' show HeroRenderer;

/// Renders a Fighter's visual representation: body, effects, telegraphs, labels.
/// Extracted from Fighter to keep the component focused on game logic.
class FighterRenderer {
  FighterRenderer._();

  /// Main render entry point. Delegates from [Fighter.render].
  static void render(Canvas canvas, Fighter f) {
    // Render culling: skip if fighter is off-screen (1280×600 world + margin)
    const margin = 100.0;
    if (f.position.x + Fighter.fighterWidth < -margin ||
        f.position.x > 1280 + margin ||
        f.position.y + Fighter.fighterHeight < -margin ||
        f.position.y > 600 + margin) {
      return;
    }

    // Flicker during invincibility
    final flickerVisible = f.invincibilityTimer <= 0 ||
        (f.invincibilityTimer * 10).floor() % 2 == 0;
    if (!flickerVisible) return;

    // Shadow
    _drawShadow(canvas, f);
    // Hero body
    _drawBody(canvas, f);
    // Death fade
    _drawDeathFade(canvas, f);
    // Attack hitbox
    _drawHitbox(canvas, f);
    // Skill telegraph
    _drawSkillTelegraph(canvas, f);
    // Status overlays
    _drawFrozen(canvas, f);
    _drawStunStars(canvas, f);
    // Name label
    _drawNameLabel(canvas, f);
    // Hit flash
    _drawHitFlash(canvas, f);
  }

  static void _drawShadow(Canvas canvas, Fighter f) {
    // Shadow shrinks and fades when airborne (jumping)
    final airborne = !f.isGrounded;
    final shadowAlpha = airborne ? 0x15 : 0x33;
    final shadowScale = airborne ? 0.4 : 1.0;
    final shadowPaint = Paint()..color = Color.fromARGB(shadowAlpha, 0, 0, 0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(Fighter.fighterWidth / 2, Fighter.fighterHeight + 5),
        width: Fighter.fighterWidth * 0.8 * shadowScale,
        height: 10 * shadowScale,
      ),
      shadowPaint,
    );
  }

  static void _drawBody(Canvas canvas, Fighter f) {
    final atkProgress = (f.state == FighterState.attack && f.currentAttackDuration > 0)
        ? (f.stateTimer / f.currentAttackDuration).clamp(0.0, 1.0)
        : 0.0;
    final hurtTimer = (f.state == FighterState.hurt) ? (f.stateTimer / Fighter.hurtDuration).clamp(0.0, 1.0) : 0.0;

    HeroRenderer.render(
      canvas: canvas,
      fighterWidth: Fighter.fighterWidth,
      fighterHeight: Fighter.fighterHeight,
      primaryColor: f.color,
      facingRight: f.facingRight,
      state: f.state.name,
      stateTimer: f.stateTimer,
      visuals: f.visuals,
      attackProgress: atkProgress,
      velocityX: f.velocity.x,
      skillVisualType: f.skillVisualType.name,
      hurtTimer: hurtTimer,
      comboIndex: f.comboHitIndex,
      animTimer: f.animTimer,
      deathProgress: f.deathTimer,
    );
  }

  static void _drawDeathFade(Canvas canvas, Fighter f) {
    if (f.state == FighterState.dead && f.deathTimer > 0.5) {
      final fadeAlpha = (1.0 - (f.deathTimer - 0.5) * 2.0).clamp(0.0, 1.0);
      f.deathFadePaint.color = Color.fromARGB((fadeAlpha * 255).round(), 255, 255, 255);
      canvas.drawRect(
        Rect.fromLTWH(-20, -20, Fighter.fighterWidth + 40, Fighter.fighterHeight + 40),
        f.deathFadePaint,
      );
    }
  }

  static void _drawHitbox(Canvas canvas, Fighter f) {
    if (f.state == FighterState.attack) {
      final atkPaint = Paint()
        ..color = const Color(0x44FFFF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final atkX = f.facingRight ? Fighter.fighterWidth : -f.currentAttackRange;
      canvas.drawRect(
        Rect.fromLTWH(atkX, 0, f.currentAttackRange, f.currentHitboxHeight),
        atkPaint,
      );
    }
  }

  static void _drawSkillTelegraph(Canvas canvas, Fighter f) {
    if (f.state != FighterState.skill) return;
    final progress = (f.stateTimer / Fighter.skillDuration).clamp(0.0, 1.0);
    final alpha = (progress * 180).round().clamp(30, 180);
    final cx = Fighter.fighterWidth / 2;
    final cy = Fighter.fighterHeight / 2;
    final c = f.color;
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    final facingRight = f.facingRight;

    switch (f.skillVisualType) {
      case SkillVisualType.spin:
        final radius = f.skillVisualRadius * (1.0 - progress * 0.3);
        final ringPaint = Paint()
          ..color = Color.fromARGB(alpha, r, g, b)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(Offset(cx, cy), radius, ringPaint);
        final glowPaint = Paint()..color = Color.fromARGB(alpha ~/ 3, r, g, b);
        canvas.drawCircle(Offset(cx, cy), radius * 0.6, glowPaint);
        for (int i = 0; i < 4; i++) {
          final angle = (1.0 - progress) * 12.0 + i * 1.5708;
          final sx = cx + cos(angle) * radius * 0.8;
          final sy = cy + sin(angle) * radius * 0.8;
          final ex = cx + cos(angle) * radius;
          final ey = cy + sin(angle) * radius;
          canvas.drawLine(Offset(sx, sy), Offset(ex, ey), ringPaint);
        }
        break;

      case SkillVisualType.dash:
        final dir = facingRight ? 1.0 : -1.0;
        final dashLen = f.skillVisualDistance * (1.0 - progress * 0.5);
        final startX = facingRight ? Fighter.fighterWidth : 0.0;
        final trailPaint = Paint()..color = Color.fromARGB(alpha ~/ 2, r, g, b);
        canvas.drawRect(
          Rect.fromLTWH(
            facingRight ? startX : startX - dashLen,
            Fighter.fighterHeight * 0.2, dashLen, Fighter.fighterHeight * 0.6,
          ),
          trailPaint,
        );
        final edgePaint = Paint()
          ..color = Color.fromARGB(alpha, 255, 255, 255)
          ..strokeWidth = 2;
        final edgeX = startX + dir * dashLen;
        canvas.drawLine(
          Offset(edgeX, Fighter.fighterHeight * 0.1),
          Offset(edgeX, Fighter.fighterHeight * 0.9),
          edgePaint,
        );
        break;

      case SkillVisualType.fan:
        final fanRadius = 80.0 + f.skillVisualProjectileCount * 8.0;
        final halfAngle = 0.15 + f.skillVisualProjectileCount * 0.08;
        final baseAngle = facingRight ? 0.0 : 3.1416;
        final fanPaint = Paint()..color = Color.fromARGB(alpha ~/ 2, r, g, b);
        final arcRect = Rect.fromCircle(
          center: Offset(facingRight ? Fighter.fighterWidth : 0, cy),
          radius: fanRadius * (1.0 - progress * 0.3),
        );
        canvas.drawArc(arcRect, baseAngle - halfAngle, halfAngle * 2, true, fanPaint);
        final borderPaint = Paint()
          ..color = Color.fromARGB(alpha, r, g, b)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawArc(arcRect, baseAngle - halfAngle, halfAngle * 2, true, borderPaint);
        break;

      case SkillVisualType.charge:
        final chargeProgress = 1.0 - progress;
        final glowRadius = 20.0 + chargeProgress * 30.0;
        final glowAlpha = (chargeProgress * 150).round().clamp(0, 150);
        final outerPaint = Paint()..color = Color.fromARGB(glowAlpha ~/ 2, r, g, b);
        canvas.drawCircle(Offset(cx, cy), glowRadius, outerPaint);
        final corePaint = Paint()..color = Color.fromARGB(glowAlpha, 255, 255, 200);
        canvas.drawCircle(Offset(cx, cy), glowRadius * 0.4, corePaint);
        final ringPaint = Paint()
          ..color = Color.fromARGB(glowAlpha, r, g, b)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius),
          -1.5708, chargeProgress * 6.2832, false, ringPaint,
        );
        break;

      case SkillVisualType.ranged:
        final dir = facingRight ? 1.0 : -1.0;
        final startX = facingRight ? Fighter.fighterWidth : 0.0;
        final linePaint = Paint()
          ..color = Color.fromARGB(alpha, r, g, b)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(startX, cy), Offset(startX + dir * 60, cy), linePaint);
        canvas.drawLine(Offset(startX + dir * 60, cy), Offset(startX + dir * 48, cy - 8), linePaint);
        canvas.drawLine(Offset(startX + dir * 60, cy), Offset(startX + dir * 48, cy + 8), linePaint);
        break;
    }
  }

  static void _drawFrozen(Canvas canvas, Fighter f) {
    if (!f.isFrozen) return;
    final freezePaint = Paint()..color = const Color(0x4400CCFF);
    final iceBorder = Paint()
      ..color = const Color(0x8800CCFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2, -2, Fighter.fighterWidth + 4, Fighter.fighterHeight + 4),
        const Radius.circular(5),
      ), freezePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2, -2, Fighter.fighterWidth + 4, Fighter.fighterHeight + 4),
        const Radius.circular(5),
      ), iceBorder);
  }

  static void _drawStunStars(Canvas canvas, Fighter f) {
    if (!f.isStunned) return;
    final starPaint = Paint()..color = const Color(0xFFFFFF00);
    for (int i = 0; i < 3; i++) {
      final angle = (f.stunTimer * 5 + i * 2.1);
      final sx = Fighter.fighterWidth / 2 + cos(angle) * 20;
      final sy = -10 + sin(angle) * 5;
      canvas.drawCircle(Offset(sx, sy), 3, starPaint);
    }
  }

  static void _drawNameLabel(Canvas canvas, Fighter f) {
    final paragraph = _buildText(f.name, 10, const Color(0xFFFFFFFF));
    canvas.drawParagraph(
      paragraph,
      Offset((Fighter.fighterWidth - paragraph.width) / 2, -16),
    );
  }

  static void _drawHitFlash(Canvas canvas, Fighter f) {
    if (f.hitFlashTimer <= 0) return;
    final flashAlpha = (f.hitFlashTimer / Fighter.hitFlashDuration).clamp(0.0, 1.0);
    final flashPaint = Paint()
      ..color = Color.fromARGB((flashAlpha * 80).round(), 255, 255, 255);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, Fighter.fighterWidth, Fighter.fighterHeight),
        const Radius.circular(5),
      ), flashPaint);
  }

  static Paragraph _buildText(String text, double fontSize, Color color) {
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: fontSize,
      maxLines: 1,
    ))
      ..pushStyle(TextStyle(color: color, fontSize: fontSize));
    builder.addText(text);
    final p = builder.build();
    p.layout(const ParagraphConstraints(width: Fighter.fighterWidth));
    return p;
  }
}
