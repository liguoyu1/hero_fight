import 'dart:math';
import 'dart:ui';

/// Body type presets for different hero archetypes
enum BodyType { normal, heavy, slim, giant }

/// Visual configuration for a hero's appearance
class HeroVisuals {
  final BodyType bodyType;
  final double headRadius;      // head size
  final double torsoWidth;      // torso width
  final double torsoHeight;     // torso height
  final double armLength;       // upper + lower arm
  final double armWidth;        // arm thickness
  final double legLength;       // upper + lower leg
  final double legWidth;        // leg thickness
  final int secondaryColor;     // accent color (armor, trim)
  final int skinColor;          // skin/face color
  final bool hasHelmet;         // draw helmet instead of hair
  final bool hasCape;           // draw cape
  final bool hasShield;         // draw shield on back arm
  final bool hasWeapon;         // draw weapon on front arm
  final double weaponLength;    // weapon size
  final int weaponColor;        // weapon color

  const HeroVisuals({
    this.bodyType = BodyType.normal,
    this.headRadius = 10,
    this.torsoWidth = 24,
    this.torsoHeight = 22,
    this.armLength = 20,
    this.armWidth = 5,
    this.legLength = 22,
    this.legWidth = 6,
    this.secondaryColor = 0xFF333333,
    this.skinColor = 0xFFFFDBAC,
    this.hasHelmet = false,
    this.hasCape = false,
    this.hasShield = false,
    this.hasWeapon = false,
    this.weaponLength = 25,
    this.weaponColor = 0xFFCCCCCC,
  });

  /// Presets
  static const normal = HeroVisuals();
  static const heavy = HeroVisuals(
    bodyType: BodyType.heavy,
    headRadius: 11,
    torsoWidth: 30,
    torsoHeight: 24,
    armLength: 22,
    armWidth: 7,
    legLength: 20,
    legWidth: 8,
  );
  static const slim = HeroVisuals(
    bodyType: BodyType.slim,
    headRadius: 9,
    torsoWidth: 20,
    torsoHeight: 20,
    armLength: 19,
    armWidth: 4,
    legLength: 24,
    legWidth: 5,
  );
  static const giant = HeroVisuals(
    bodyType: BodyType.giant,
    headRadius: 13,
    torsoWidth: 34,
    torsoHeight: 26,
    armLength: 24,
    armWidth: 8,
    legLength: 22,
    legWidth: 9,
  );
}

/// Pose angles for limbs (in radians)
class _LimbPose {
  final double frontArmUpper;
  final double frontArmLower;
  final double backArmUpper;
  final double backArmLower;
  final double frontLegUpper;
  final double frontLegLower;
  final double backLegUpper;
  final double backLegLower;
  final double torsoLean;     // forward/backward lean
  final double headTilt;

  const _LimbPose({
    this.frontArmUpper = 0.3,
    this.frontArmLower = 0.2,
    this.backArmUpper = -0.3,
    this.backArmLower = -0.2,
    this.frontLegUpper = 0.1,
    this.frontLegLower = 0,
    this.backLegUpper = -0.1,
    this.backLegLower = 0,
    this.torsoLean = 0,
    this.headTilt = 0,
  });
}

/// Renders a hero as an articulated figure with limbs and animations
class HeroRenderer {
  HeroRenderer._();

  /// Main render entry point
  static void render({
    required Canvas canvas,
    required double fighterWidth,
    required double fighterHeight,
    required Color primaryColor,
    required bool facingRight,
    required String state,       // idle/walk/jump/attack/skill/hurt/dead
    required double stateTimer,
    required HeroVisuals visuals,
    double attackProgress = 0,   // 0..1 for attack animation
    double velocityX = 0,        // horizontal velocity for stride/tilt
    String skillVisualType = 'ranged', // spin/dash/fan/charge/ranged
    double hurtTimer = 0,        // damage recoil frame
    int comboIndex = 0,          // current combo hit (0/1/2) for attack variation
    double animTimer = 0,        // continuous animation timer
    double deathProgress = 0,    // 0..1 progressive death animation
  }) {
    final cx = fighterWidth / 2;
    final cy = fighterHeight * 0.35; // shoulder pivot point

    canvas.save();
    if (!facingRight) {
      canvas.translate(fighterWidth, 0);
      canvas.scale(-1, 1);
    }

    // Movement tilt and stride offset
    double bodyTilt = 0;
    double strideOffset = 0;
    double verticalBob = 0;
    if (state == 'walk' && velocityX.abs() > 10) {
      // Add body tilt based on movement direction
      bodyTilt = (velocityX > 0 ? 1 : -1) * 0.08;
      // Stride offset for running effect (use animTimer for smooth continuous cycle)
      strideOffset = sin(animTimer * 12) * 3;
      // Vertical bob — 2-frame bounce cycle
      verticalBob = sin(animTimer * 24).abs() * -3;
    }

    // Apply movement tilt
    canvas.translate(cx + strideOffset, cy + verticalBob);
    canvas.rotate(bodyTilt);
    canvas.translate(-cx - strideOffset, -cy - verticalBob);

    // Damage recoil/stagger - brief backward lean
    double recoilOffset = 0;
    if (state == 'hurt' && hurtTimer > 0) {
      // Multi-phase recoil: sharp snap back → hold → ease out
      final phase = hurtTimer.clamp(0.0, 1.0);
      if (phase > 0.7) {
        // Impact snap (0.7-1.0): sharp backward jolt
        recoilOffset = -8 * ((phase - 0.7) / 0.3);
      } else if (phase > 0.3) {
        // Stagger hold (0.3-0.7): hold recoil position
        recoilOffset = -8;
      } else {
        // Recovery (0-0.3): ease back to neutral
        recoilOffset = -8 * (phase / 0.3);
      }
    }

    // Death animation: progressive collapse
    double deathTilt = 0;
    double deathDrop = 0;
    if (state == 'dead' && deathProgress > 0) {
      // Phase 1 (0-0.4): stumble backward
      // Phase 2 (0.4-0.7): knees buckle, drop
      // Phase 3 (0.7-1.0): collapse to ground
      if (deathProgress < 0.4) {
        final p = deathProgress / 0.4;
        deathTilt = -p * 0.3;
        deathDrop = p * 5;
      } else if (deathProgress < 0.7) {
        final p = (deathProgress - 0.4) / 0.3;
        deathTilt = -0.3 - p * 0.5;
        deathDrop = 5 + p * 15;
      } else {
        final p = (deathProgress - 0.7) / 0.3;
        deathTilt = -0.8 - p * 0.4;
        deathDrop = 20 + p * 10;
      }
      canvas.translate(cx, cy);
      canvas.rotate(deathTilt);
      canvas.translate(-cx, -cy + deathDrop);
    }

    final pose = _getPose(state, stateTimer, attackProgress, skillVisualType,
        comboIndex: comboIndex, animTimer: animTimer, deathProgress: deathProgress);

    // Cape (behind everything)
    if (visuals.hasCape) {
      _drawCape(canvas, cx, cy, visuals, primaryColor, pose);
    }

    // Back arm
    _drawArm(canvas, cx - visuals.torsoWidth * 0.4 + recoilOffset, cy + 2,
        pose.backArmUpper, pose.backArmLower,
        visuals, _darken(primaryColor, 0.7));

    // Back leg
    _drawLeg(canvas, cx - visuals.torsoWidth * 0.15 + strideOffset, cy + visuals.torsoHeight,
        pose.backLegUpper, pose.backLegLower,
        visuals, _darken(primaryColor, 0.7));

    // Torso
    _drawTorso(canvas, cx + recoilOffset, cy, visuals, primaryColor, pose);

    // Front leg
    _drawLeg(canvas, cx + visuals.torsoWidth * 0.15 - strideOffset, cy + visuals.torsoHeight,
        pose.frontLegUpper, pose.frontLegLower,
        visuals, primaryColor);

    // Front arm + weapon (attack shows arm extension)
    final armExtension = (state == 'attack') ? attackProgress * 0.3 : 0.0;
    _drawArm(canvas, cx + visuals.torsoWidth * 0.4 + recoilOffset, cy + 2,
        pose.frontArmUpper + armExtension, pose.frontArmLower,
        visuals, primaryColor);

    if (visuals.hasWeapon && state == 'attack') {
      _drawWeapon(canvas, cx + visuals.torsoWidth * 0.4 + recoilOffset, cy + 2,
          pose.frontArmUpper + armExtension, visuals, attackProgress);
    }

    // Shield on back arm
    if (visuals.hasShield) {
      _drawShield(canvas, cx - visuals.torsoWidth * 0.4 + recoilOffset, cy + 2,
          pose.backArmUpper, visuals);
    }

    // Head
    _drawHead(canvas, cx + recoilOffset, cy - 2, visuals, primaryColor, facingRight, pose);

    canvas.restore();
  }

  static _LimbPose _getPose(String state, double timer, double atkProgress, String skillVisualType, {
    int comboIndex = 0,
    double animTimer = 0,
    double deathProgress = 0,
  }) {
    switch (state) {
      case 'idle':
        final breathe = sin(animTimer * 2.5) * 0.05;
        return _LimbPose(
          frontArmUpper: 0.2 + breathe,
          frontArmLower: 0.3,
          backArmUpper: -0.2 + breathe,
          backArmLower: -0.3,
          frontLegUpper: 0.05,
          backLegUpper: -0.05,
          torsoLean: breathe * 0.5,
        );
      case 'walk':
        // Enhanced walk cycle with arm pump and knee lift
        final cycle = sin(animTimer * 10);
        final kneeLift = max(0.0, sin(animTimer * 20)) * 0.2;
        return _LimbPose(
          frontArmUpper: -cycle * 0.7,
          frontArmLower: -0.5 - cycle.abs() * 0.2,
          backArmUpper: cycle * 0.7,
          backArmLower: -0.5 - cycle.abs() * 0.2,
          frontLegUpper: cycle * 0.6,
          frontLegLower: max(0, -cycle * 0.4) + kneeLift,
          backLegUpper: -cycle * 0.6,
          backLegLower: max(0, cycle * 0.4) + kneeLift,
          torsoLean: 0.08,
        );
      case 'jump':
        return const _LimbPose(
          frontArmUpper: -0.8,
          frontArmLower: -0.3,
          backArmUpper: -0.6,
          backArmLower: -0.3,
          frontLegUpper: 0.4,
          frontLegLower: 0.6,
          backLegUpper: -0.3,
          backLegLower: 0.4,
        );
      case 'attack':
        return _getComboAttackPose(atkProgress, comboIndex);
      case 'skill':
        // Skill cast animations based on skillVisualType
        final t = (timer * 4).clamp(0.0, 1.0);
        final skillPose = _getSkillPose(skillVisualType, t);
        return _LimbPose(
          frontArmUpper: skillPose.frontArmUpper,
          frontArmLower: skillPose.frontArmLower,
          backArmUpper: skillPose.backArmUpper,
          backArmLower: skillPose.backArmLower,
          frontLegUpper: skillPose.frontLegUpper,
          backLegUpper: skillPose.backLegUpper,
          torsoLean: skillPose.torsoLean,
        );
      case 'hurt':
        return _getHurtPose(timer);
      case 'dead':
        return _getDeathPose(deathProgress);
      default:
        return const _LimbPose();
    }
  }

  // ── Drawing helpers ──

  static void _drawTorso(Canvas canvas, double cx, double cy,
      HeroVisuals v, Color color, _LimbPose pose) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(pose.torsoLean);

    final w = v.torsoWidth;
    final h = v.torsoHeight;
    final bodyPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = _darken(color, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Main torso shape
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(w * 0.2),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, borderPaint);

    // Belt / waist line
    final beltPaint = Paint()
      ..color = Color(v.secondaryColor)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-w * 0.4, h * 0.4),
      Offset(w * 0.4, h * 0.4),
      beltPaint,
    );

    // Chest detail (V-shape or line)
    final detailPaint = Paint()
      ..color = Color(v.secondaryColor).withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(-w * 0.15, -h * 0.35)
      ..lineTo(0, -h * 0.1)
      ..lineTo(w * 0.15, -h * 0.35);
    canvas.drawPath(path, detailPaint);

    canvas.restore();
  }

  static void _drawHead(Canvas canvas, double cx, double cy,
      HeroVisuals v, Color color, bool facingRight, _LimbPose pose) {
    canvas.save();
    canvas.translate(cx, cy - v.headRadius);
    canvas.rotate(pose.headTilt);

    final r = v.headRadius;
    final skinPaint = Paint()..color = Color(v.skinColor);
    final borderPaint = Paint()
      ..color = _darken(Color(v.skinColor), 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Head circle
    canvas.drawCircle(Offset.zero, r, skinPaint);
    canvas.drawCircle(Offset.zero, r, borderPaint);

    // Helmet or hair
    if (v.hasHelmet) {
      final helmetPaint = Paint()..color = Color(v.secondaryColor);
      final helmetPath = Path()
        ..moveTo(-r, 0)
        ..quadraticBezierTo(-r, -r * 1.2, 0, -r * 1.1)
        ..quadraticBezierTo(r, -r * 1.2, r, 0)
        ..close();
      canvas.drawPath(helmetPath, helmetPaint);
      canvas.drawPath(helmetPath, borderPaint);
    } else {
      // Hair tuft
      final hairPaint = Paint()..color = _darken(color, 0.8);
      final hairPath = Path()
        ..moveTo(-r * 0.6, -r * 0.5)
        ..quadraticBezierTo(-r * 0.2, -r * 1.4, r * 0.3, -r * 0.8)
        ..quadraticBezierTo(r * 0.6, -r * 1.2, r * 0.5, -r * 0.4)
        ..lineTo(r * 0.3, -r * 0.3)
        ..quadraticBezierTo(0, -r * 0.9, -r * 0.4, -r * 0.3)
        ..close();
      canvas.drawPath(hairPath, hairPaint);
    }

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFFFFFFFF);
    final pupilPaint = Paint()..color = const Color(0xFF111111);
    final eyeOffX = r * 0.3;
    final eyeY = -r * 0.05;
    final eyeR = r * 0.28;
    final pupilR = r * 0.15;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(eyeOffX - 1, eyeY), width: eyeR * 2, height: eyeR * 1.6),
      eyePaint,
    );
    canvas.drawCircle(Offset(eyeOffX + 1, eyeY), pupilR, pupilPaint);

    // Mouth (small line)
    final mouthPaint = Paint()
      ..color = const Color(0xFF663333)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(eyeOffX - r * 0.2, r * 0.4),
      Offset(eyeOffX + r * 0.15, r * 0.35),
      mouthPaint,
    );

    canvas.restore();
  }

  static void _drawArm(Canvas canvas, double x, double y,
      double upperAngle, double lowerAngle,
      HeroVisuals v, Color color) {
    final upperLen = v.armLength * 0.5;
    final lowerLen = v.armLength * 0.5;
    final w = v.armWidth;

    canvas.save();
    canvas.translate(x, y);

    // Upper arm
    canvas.save();
    canvas.rotate(upperAngle);
    _drawLimb(canvas, upperLen, w, color);

    // Lower arm (elbow joint)
    canvas.translate(0, upperLen);
    canvas.rotate(lowerAngle);
    _drawLimb(canvas, lowerLen, w * 0.85, color);

    // Hand
    final handPaint = Paint()..color = Color(v.skinColor);
    canvas.drawCircle(Offset(0, lowerLen), w * 0.6, handPaint);

    canvas.restore();
    canvas.restore();
  }

  static void _drawLeg(Canvas canvas, double x, double y,
      double upperAngle, double lowerAngle,
      HeroVisuals v, Color color) {
    final upperLen = v.legLength * 0.5;
    final lowerLen = v.legLength * 0.5;
    final w = v.legWidth;

    canvas.save();
    canvas.translate(x, y);

    // Upper leg
    canvas.save();
    canvas.rotate(upperAngle);
    _drawLimb(canvas, upperLen, w, _darken(color, 0.85));

    // Lower leg (knee joint)
    canvas.translate(0, upperLen);
    canvas.rotate(lowerAngle);
    _drawLimb(canvas, lowerLen, w * 0.85, _darken(color, 0.85));

    // Foot
    final footPaint = Paint()..color = Color(v.secondaryColor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.5, lowerLen - 2, w * 1.5, w * 0.7),
        Radius.circular(w * 0.2),
      ),
      footPaint,
    );

    canvas.restore();
    canvas.restore();
  }

  static void _drawLimb(Canvas canvas, double length, double width, Color color) {
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = _darken(color, 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-width / 2, 0, width, length),
      Radius.circular(width * 0.4),
    );
    canvas.drawRRect(rect, paint);
    canvas.drawRRect(rect, borderPaint);

    // Joint circle at top
    final jointPaint = Paint()..color = _darken(color, 0.75);
    canvas.drawCircle(Offset(0, 0), width * 0.4, jointPaint);
  }

  static void _drawWeapon(Canvas canvas, double x, double y,
      double armAngle, HeroVisuals v, double atkProgress) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(armAngle);
    canvas.translate(0, v.armLength * 0.9);

    final weaponPaint = Paint()..color = Color(v.weaponColor);
    final glowPaint = Paint()
      ..color = Color(v.weaponColor).withValues(alpha: 0.3 + atkProgress * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Weapon glow during attack
    if (atkProgress > 0.3) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-3, 0, 6, v.weaponLength + 4),
          const Radius.circular(3),
        ),
        glowPaint,
      );
    }

    // Weapon blade
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2, 0, 4, v.weaponLength),
        const Radius.circular(2),
      ),
      weaponPaint,
    );

    // Handle
    final handlePaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-3, -4, 6, 6),
        const Radius.circular(1),
      ),
      handlePaint,
    );

    canvas.restore();
  }

  static void _drawShield(Canvas canvas, double x, double y,
      double armAngle, HeroVisuals v) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(armAngle);
    canvas.translate(0, v.armLength * 0.4);

    final shieldPaint = Paint()..color = Color(v.secondaryColor);
    final borderPaint = Paint()
      ..color = _darken(Color(v.secondaryColor), 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Shield shape
    final path = Path()
      ..moveTo(0, -10)
      ..quadraticBezierTo(-12, -8, -12, 2)
      ..quadraticBezierTo(-10, 14, 0, 16)
      ..quadraticBezierTo(10, 14, 12, 2)
      ..quadraticBezierTo(12, -8, 0, -10)
      ..close();
    canvas.drawPath(path, shieldPaint);
    canvas.drawPath(path, borderPaint);

    // Star emblem
    final starPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(const Offset(0, 3), 4, starPaint);

    canvas.restore();
  }

  static void _drawCape(Canvas canvas, double cx, double cy,
      HeroVisuals v, Color color, _LimbPose pose) {
    canvas.save();
    canvas.translate(cx, cy);

    final capePaint = Paint()..color = _darken(color, 0.7).withValues(alpha: 0.8);
    final capeW = v.torsoWidth * 0.8;
    final capeH = v.torsoHeight * 1.5;
    final sway = sin(pose.torsoLean * 5) * 3;

    final path = Path()
      ..moveTo(-capeW * 0.3, -2)
      ..lineTo(-capeW * 0.5, 0)
      ..quadraticBezierTo(-capeW * 0.6 + sway, capeH * 0.6, -capeW * 0.4 + sway, capeH)
      ..lineTo(capeW * 0.1 + sway, capeH * 0.9)
      ..quadraticBezierTo(capeW * 0.2, capeH * 0.5, capeW * 0.1, 0)
      ..close();
    canvas.drawPath(path, capePaint);

    canvas.restore();
  }

  static Color _darken(Color c, double factor) {
    return Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      (c.r * 255 * factor).round().clamp(0, 255),
      (c.g * 255 * factor).round().clamp(0, 255),
      (c.b * 255 * factor).round().clamp(0, 255),
    );
  }

  /// Combo-aware attack poses — different stances for combo hit 0/1/2
  static _LimbPose _getComboAttackPose(double t, int comboIndex) {
    final stance = comboIndex % 3;
    switch (stance) {
      case 0:
        return _getAttackPoseHorizontal(t);
      case 1:
        return _getAttackPoseUppercut(t);
      case 2:
      default:
        return _getAttackPoseFinisher(t);
    }
  }

  /// Combo 1: horizontal slash (default swing)
  static _LimbPose _getAttackPoseHorizontal(double t) {
    // Wind-up (0-0.3), strike (0.3-0.6), recover (0.6-1.0)
    if (t < 0.3) {
      final p = t / 0.3;
      return _LimbPose(
        frontArmUpper: 0.2 - p * 1.5,
        frontArmLower: 0.3 - p * 0.8,
        backArmUpper: -0.2 - p * 0.3,
        backArmLower: -0.3,
        torsoLean: -p * 0.1,
      );
    } else if (t < 0.6) {
      final p = (t - 0.3) / 0.3;
      return _LimbPose(
        frontArmUpper: -1.3 + p * 2.0,
        frontArmLower: -0.5 + p * 0.3,
        backArmUpper: -0.5,
        backArmLower: -0.3,
        torsoLean: -0.1 + p * 0.2,
        frontLegUpper: p * 0.15,
      );
    } else {
      final p = (t - 0.6) / 0.4;
      return _LimbPose(
        frontArmUpper: 0.7 - p * 0.5,
        frontArmLower: -0.2 + p * 0.5,
        backArmUpper: -0.5 + p * 0.3,
        backArmLower: -0.3,
        torsoLean: 0.1 - p * 0.1,
      );
    }
  }

  /// Combo 2: uppercut — rising arc, knee lift
  static _LimbPose _getAttackPoseUppercut(double t) {
    if (t < 0.25) {
      // Crouch wind-up
      final p = t / 0.25;
      return _LimbPose(
        frontArmUpper: 0.6 + p * 0.4,
        frontArmLower: 0.5,
        backArmUpper: 0.4 + p * 0.3,
        backArmLower: 0.3,
        frontLegUpper: 0.2 + p * 0.15,
        backLegUpper: 0.1,
        torsoLean: 0.1 + p * 0.15,
      );
    } else if (t < 0.55) {
      // Explosive uppercut rise
      final p = (t - 0.25) / 0.3;
      return _LimbPose(
        frontArmUpper: 1.0 - p * 3.0,    // sweep up
        frontArmLower: 0.5 - p * 1.0,
        backArmUpper: 0.7 - p * 0.5,
        backArmLower: 0.3,
        frontLegUpper: 0.35 - p * 0.2,
        backLegUpper: 0.1 - p * 0.3,    // back leg drives up
        torsoLean: 0.25 - p * 0.4,
      );
    } else {
      // Recovery
      final p = (t - 0.55) / 0.45;
      return _LimbPose(
        frontArmUpper: -2.0 + p * 2.2,
        frontArmLower: -0.5 + p * 0.8,
        backArmUpper: 0.2 - p * 0.4,
        backArmLower: 0.3 - p * 0.6,
        frontLegUpper: 0.15 - p * 0.1,
        backLegUpper: -0.2 + p * 0.15,
        torsoLean: -0.15 + p * 0.15,
      );
    }
  }

  /// Combo 3: finisher — heavy overhead slam, forward lunge
  static _LimbPose _getAttackPoseFinisher(double t) {
    if (t < 0.35) {
      // Big overhead wind-up
      final p = t / 0.35;
      return _LimbPose(
        frontArmUpper: 0.3 - p * 2.6,    // raise way up
        frontArmLower: 0.2 - p * 0.6,
        backArmUpper: -0.3 - p * 0.8,
        backArmLower: -0.3 - p * 0.3,
        frontLegUpper: 0.1 + p * 0.15,
        backLegUpper: -0.1 - p * 0.2,
        torsoLean: -p * 0.25,
      );
    } else if (t < 0.65) {
      // Slam down with body weight
      final p = (t - 0.35) / 0.3;
      return _LimbPose(
        frontArmUpper: -2.3 + p * 3.5,    // crash down
        frontArmLower: -0.4 + p * 0.7,
        backArmUpper: -1.1 + p * 0.8,
        backArmLower: -0.6,
        frontLegUpper: 0.25 + p * 0.2,    // step forward
        backLegUpper: -0.3 - p * 0.1,
        torsoLean: -0.25 + p * 0.5,        // lunge forward
      );
    } else {
      // Hold finish + recover
      final p = (t - 0.65) / 0.35;
      return _LimbPose(
        frontArmUpper: 1.2 - p * 1.0,
        frontArmLower: 0.3 - p * 0.1,
        backArmUpper: -0.3 + p * 0.1,
        backArmLower: -0.6 + p * 0.3,
        frontLegUpper: 0.45 - p * 0.4,
        backLegUpper: -0.4 + p * 0.35,
        torsoLean: 0.25 - p * 0.25,
      );
    }
  }

  /// Hurt pose — multi-phase: impact → stagger → recover
  /// hurtTimer is normalized 0..1 where 1.0 = freshly hit, 0.0 = recovering
  static _LimbPose _getHurtPose(double remainingTimer) {
    // Convert: 1.0 = just hit, 0.0 = end of hurt
    final t = remainingTimer.clamp(0.0, 1.0);
    if (t > 0.7) {
      // Impact phase — sharp recoil, arms thrown back
      final p = (t - 0.7) / 0.3;
      return _LimbPose(
        frontArmUpper: 0.5 + p * 0.6,
        frontArmLower: 0.8 + p * 0.4,
        backArmUpper: 0.3 + p * 0.5,
        backArmLower: 0.6 + p * 0.3,
        frontLegUpper: -0.1 - p * 0.15,
        backLegUpper: 0.2 + p * 0.15,
        torsoLean: -0.15 - p * 0.15,
        headTilt: -0.2 - p * 0.15,
      );
    } else if (t > 0.3) {
      // Stagger hold — arms still raised, leaning back
      return const _LimbPose(
        frontArmUpper: 0.7,
        frontArmLower: 0.9,
        backArmUpper: 0.5,
        backArmLower: 0.7,
        frontLegUpper: -0.18,
        backLegUpper: 0.28,
        torsoLean: -0.22,
        headTilt: -0.28,
      );
    } else {
      // Recover — easing back toward neutral
      final p = t / 0.3; // 1.0 → 0.0
      return _LimbPose(
        frontArmUpper: 0.2 + p * 0.5,
        frontArmLower: 0.3 + p * 0.6,
        backArmUpper: -0.2 + p * 0.7,
        backArmLower: -0.3 + p * 1.0,
        frontLegUpper: -p * 0.1,
        backLegUpper: p * 0.2,
        torsoLean: -p * 0.15,
        headTilt: -p * 0.15,
      );
    }
  }

  /// Death pose — progressive collapse from stumble to ground
  static _LimbPose _getDeathPose(double progress) {
    if (progress < 0.4) {
      // Stumble backward
      final p = progress / 0.4;
      return _LimbPose(
        frontArmUpper: 0.5 + p * 0.4,
        frontArmLower: 0.5 + p * 0.3,
        backArmUpper: 0.3 + p * 0.4,
        backArmLower: 0.4 + p * 0.3,
        frontLegUpper: -0.1 - p * 0.2,
        backLegUpper: 0.2 + p * 0.2,
        torsoLean: -0.2 - p * 0.1,
        headTilt: -0.2 - p * 0.1,
      );
    } else if (progress < 0.7) {
      // Knees buckle
      final p = (progress - 0.4) / 0.3;
      return _LimbPose(
        frontArmUpper: 0.9 + p * 0.3,
        frontArmLower: 0.8 - p * 0.3,
        backArmUpper: 0.7 + p * 0.3,
        backArmLower: 0.7 - p * 0.2,
        frontLegUpper: -0.3 + p * 1.0,
        frontLegLower: p * 0.6,
        backLegUpper: 0.4 + p * 0.3,
        backLegLower: p * 0.4,
        torsoLean: -0.3 - p * 0.1,
        headTilt: -0.3 - p * 0.0,
      );
    } else {
      // Final collapse on ground
      final p = (progress - 0.7) / 0.3;
      return _LimbPose(
        frontArmUpper: 1.2 - p * 0.4,
        frontArmLower: 0.5 - p * 0.2,
        backArmUpper: 1.0 - p * 0.3,
        backArmLower: 0.5 - p * 0.2,
        frontLegUpper: 0.7 + p * 0.3,
        frontLegLower: 0.6 - p * 0.4,
        backLegUpper: 0.7 - p * 0.1,
        backLegLower: 0.4 - p * 0.3,
        torsoLean: -0.4 - p * 0.1,
        headTilt: -0.3 - p * 0.05,
      );
    }
  }

  // Legacy API kept for backward compatibility (unused after combo system)
  // ignore: unused_element
  static _LimbPose _getAttackPose(double t) => _getAttackPoseHorizontal(t);

  /// Skill-specific cast poses based on SkillVisualType
  static _LimbPose _getSkillPose(String skillType, double t) {
    switch (skillType) {
      case 'spin':
        // AoE spin attack - arms out wide, rotating
        final spinAngle = t * 3.14159 * 2; // Full rotation
        return _LimbPose(
          frontArmUpper: -1.5 + sin(spinAngle) * 0.3,
          frontArmLower: -0.8,
          backArmUpper: 1.5 - sin(spinAngle) * 0.3,
          backArmLower: 0.8,
          frontLegUpper: 0.3 - t * 0.1,
          backLegUpper: -0.2 + t * 0.1,
          torsoLean: -0.2,
        );
      case 'dash':
        // Forward dash - leaning forward, arms thrust forward
        return _LimbPose(
          frontArmUpper: -1.8 + t * 0.6,
          frontArmLower: -0.3,
          backArmUpper: -1.2 + t * 0.4,
          backArmLower: -0.5,
          frontLegUpper: 0.5 - t * 0.3,
          backLegUpper: 0.1,
          torsoLean: 0.3,
        );
      case 'fan':
        // Multi-projectile spread - arms wide, ready to launch
        return _LimbPose(
          frontArmUpper: -1.0 - t * 0.3,
          frontArmLower: -1.2,
          backArmUpper: 1.0 + t * 0.3,
          backArmLower: -1.2,
          frontLegUpper: 0.15,
          backLegUpper: -0.15,
          torsoLean: 0,
        );
      case 'charge':
        // Charge-up - arms raised, gathering energy
        final chargeRise = t * 0.5;
        return _LimbPose(
          frontArmUpper: -2.0 + chargeRise,
          frontArmLower: -0.2,
          backArmUpper: -1.5 + chargeRise * 0.8,
          backArmLower: -0.3,
          frontLegUpper: 0.2,
          backLegUpper: -0.1,
          torsoLean: -0.15,
        );
      case 'ranged':
      default:
        // Default ranged - pointing forward
        return _LimbPose(
          frontArmUpper: -1.2 + t * 0.5,
          frontArmLower: -0.5 + t * 0.8,
          backArmUpper: -0.8 + t * 0.3,
          backArmLower: -0.6,
          frontLegUpper: 0.2,
          backLegUpper: -0.3,
          torsoLean: -0.1 + t * 0.15,
        );
    }
  }
}
