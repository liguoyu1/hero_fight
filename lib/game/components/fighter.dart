import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../heroes/hero_data.dart';
import '../audio/sound_manager.dart';
import 'projectile.dart';
import 'hero_renderer.dart';

/// Fighter states
enum FighterState { idle, walk, jump, attack, skill, hurt, dead }

/// Skill visual archetype — determines cast animation style
enum SkillVisualType {
  spin,       // AoE circle (吕布)
  dash,       // Forward dash + projectile (关羽, 李信)
  fan,        // Multi-projectile spread (诸葛亮, 貂蝉)
  charge,     // Charge-up then release (钢铁侠)
  ranged,     // Single/few directional projectiles (default)
}

/// Input command structure for a fighter
class FighterInput {
  bool left = false;
  bool right = false;
  bool up = false;
  bool down = false;
  bool jump = false;
  bool attack = false;
  bool skill = false;

  /// Frame number this input was generated on (-1 = unknown).
  int frame = -1;

  /// Create an empty input (all buttons released).
  FighterInput.empty();

  FighterInput({
    this.left = false,
    this.right = false,
    this.up = false,
    this.down = false,
    this.jump = false,
    this.attack = false,
    this.skill = false,
    this.frame = -1,
  });

  /// Deep copy for storing in ring buffers.
  FighterInput copy() => FighterInput(
        left: left,
        right: right,
        up: up,
        down: down,
        jump: jump,
        attack: attack,
        skill: skill,
        frame: frame,
      );

  /// Overwrite this input with values from [other], preserving [frame].
  void copyFrom(FighterInput other) {
    left = other.left;
    right = other.right;
    up = other.up;
    down = other.down;
    jump = other.jump;
    attack = other.attack;
    skill = other.skill;
  }
}

/// Fighter component - the core character in the game
class Fighter extends PositionComponent {
  // Identity
  final int playerIndex; // 0 = P1, 1 = P2
  final String name;
  final String heroId;
  final Color color;

  // Stats
  double hp;
  double maxHp;
  double speed;
  double jumpForce;
  double attackPower;
  double defense;
  double skillCooldown;
  double skillCooldownTimer = 0;

  // Hero combat profile (optional — null = use defaults)
  final NormalAttackProfile? normalAttackProfile;
  final List<DirectionalAttack> directionalAttacks;

  // Visual appearance
  final HeroVisuals visuals;

  // VFX
  double hitFlashTimer = 0;
  static const double hitFlashDuration = 0.12;

  // Animation tracking
  double _animTimer = 0;        // continuous timer for cyclic animations
  double _deathTimer = 0;       // progressive death animation (0→1)
  static const double deathAnimDuration = 0.6;

  // Physics
  Vector2 velocity = Vector2.zero();
  bool facingRight = true;

  // State machine
  FighterState state = FighterState.idle;
  double stateTimer = 0;

  // Combat
  double invincibilityTimer = 0;
  double stunTimer = 0;
  double freezeTimer = 0;
  bool _attackHit = false;

  // Combo tracking
  int _comboHitIndex = 0;
  double _comboResetTimer = 0;
  static const double _comboResetDelay = 0.8;

  // Public combo accessors for HUD
  int get comboHitIndex => _comboHitIndex;
  bool get isInCombo => _comboResetTimer > 0;

  // Skill visual presentation
  SkillVisualType skillVisualType = SkillVisualType.ranged;
  double skillVisualRadius = 0;    // for spin: AoE radius
  double skillVisualDistance = 0;  // for dash: dash distance
  int skillVisualProjectileCount = 0; // for fan: number of projectiles

  // Current attack parameters (set when attack starts)
  double _currentAttackRange = 60;
  double _currentAttackDuration = 0.3;
  double _currentAttackDamage = 10;
  double _currentKnockbackX = 200;
  double _currentKnockbackY = -100;
  double _currentHitboxHeight = 70;
  double _currentLungeSpeed = 80;
  OnHitEffect _currentOnHitEffect = OnHitEffect.none;
  double _currentEffectDuration = 0;

  // Input
  final FighterInput input = FighterInput();

  // Reference to opponent (set by game)
  Fighter? opponent;

  // Callback for skill projectiles
  List<Projectile> Function(Fighter fighter)? onSkillExecute;

  // Callback when a melee attack lands
  void Function(Fighter target, double damage)? onAttackHit;

  // Constants
  static const double gravity = 600;
  static const double groundY = 520;
  static const double fighterWidth = 50;
  static const double fighterHeight = 70;
  static const double friction = 800;
  static const double attackRange = 60;
  static const double attackDuration = 0.3;
  static const double hurtDuration = 0.3;
  static const double skillDuration = 0.4;
  static const double invincibilityDuration = 0.5;

  // Screen wrapping boundaries (match stage size)
  static const double wrapMinX = 0;
  static const double wrapMaxX = 1280;
  static const double wrapMinY = -50;
  static const double wrapMaxY = 600;

  Fighter({
    required this.playerIndex,
    required this.name,
    this.heroId = '',
    required this.color,
    this.maxHp = 100,
    this.speed = 250,
    this.jumpForce = 400,
    this.attackPower = 10,
    this.defense = 0,
    this.skillCooldown = 3.0,
    this.normalAttackProfile,
    this.directionalAttacks = const [],
    this.visuals = const HeroVisuals(),
    this.onSkillExecute,
    this.onAttackHit,
    Vector2? initialPosition,
  }) : hp = maxHp {
    size = Vector2(fighterWidth, fighterHeight);
    position = initialPosition ?? Vector2(200, groundY - fighterHeight);
    facingRight = playerIndex == 0;
  }

  bool get isAlive => hp > 0;
  bool get isInvincible => invincibilityTimer > 0;
  bool get isStunned => stunTimer > 0;
  bool get isFrozen => freezeTimer > 0;
  bool get canAct =>
      isAlive &&
      !isStunned &&
      !isFrozen &&
      state != FighterState.hurt &&
      state != FighterState.dead;
  bool get canAttack =>
      canAct && state != FighterState.attack && state != FighterState.skill;
  bool get canUseSkill => canAttack && skillCooldownTimer <= 0;

  @override
  void update(double dt) {
    super.update(dt);
    // Continuous animation timer
    _animTimer += dt;

    if (state == FighterState.dead) {
      // Progress death animation
      if (_deathTimer < 1.0) {
        _deathTimer = (_deathTimer + dt / deathAnimDuration).clamp(0.0, 1.0);
      }
      return;
    }

    // Timers
    if (invincibilityTimer > 0) invincibilityTimer -= dt;
    if (stunTimer > 0) stunTimer -= dt;
    if (freezeTimer > 0) freezeTimer -= dt;
    if (skillCooldownTimer > 0) skillCooldownTimer -= dt;
    if (stateTimer > 0) stateTimer -= dt;
    if (hitFlashTimer > 0) hitFlashTimer -= dt;

    // Combo reset timer
    if (_comboResetTimer > 0) {
      _comboResetTimer -= dt;
      if (_comboResetTimer <= 0) _comboHitIndex = 0;
    }

    // State timer expiry
    if (stateTimer <= 0) {
      if (state == FighterState.attack ||
          state == FighterState.skill ||
          state == FighterState.hurt) {
        state = FighterState.idle;
      }
    }

    // Frozen = skip movement/input
    if (isFrozen) return;

    // Process input (8-direction movement)
    if (canAct) _processInput();

    // Auto-face opponent
    if (opponent != null &&
        state != FighterState.attack &&
        state != FighterState.skill) {
      facingRight = opponent!.position.x > position.x;
    }

    // Apply velocity directly
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;

    // Screen wrapping (infinite canvas)
    _checkScreenWrap();

    // Attack hitbox check
    if (state == FighterState.attack && !_attackHit &&
        stateTimer < _currentAttackDuration * 0.5) {
      _checkAttackHit();
    }
  }

  /// Wraps the fighter around screen edges.
  void _checkScreenWrap() {
    if (position.x + fighterWidth < wrapMinX) {
      position.x = wrapMaxX;
    } else if (position.x > wrapMaxX) {
      position.x = wrapMinX - fighterWidth;
    }
    if (position.y + fighterHeight < wrapMinY) {
      position.y = wrapMaxY;
    } else if (position.y > wrapMaxY) {
      position.y = wrapMinY - fighterHeight;
    }
  }

  /// Determine directional input relative to facing direction
  AttackDirection _getAttackDirection() {
    if (input.up) return AttackDirection.up;
    if (input.down) return AttackDirection.down;
    // "forward" = moving toward opponent
    final movingForward = facingRight ? input.right : input.left;
    final movingBackward = facingRight ? input.left : input.right;
    if (movingForward) return AttackDirection.forward;
    if (movingBackward) return AttackDirection.backward;
    return AttackDirection.neutral;
  }

  void _processInput() {
    if (state == FighterState.attack || state == FighterState.skill) return;

    // 8-direction movement
    double moveX = 0, moveY = 0;
    if (input.left) moveX -= 1;
    if (input.right) moveX += 1;
    if (input.up) moveY -= 1;
    if (input.down) moveY += 1;

    // Jump (vertical burst)
    if (input.jump) {
      moveY -= 1.5;
      SoundManager().playJump();
    }

    if (moveX != 0 || moveY != 0) {
      final dir = Vector2(moveX, moveY).normalized();
      velocity.x = dir.x * speed;
      velocity.y = dir.y * speed;
      state = FighterState.walk;
    } else {
      velocity.x = 0;
      velocity.y = 0;
      if (state == FighterState.walk) {
        state = FighterState.idle;
      }
    }

    // Attack — check for directional attack first
    if (input.attack && canAttack) {
      final dir = _getAttackDirection();
      _startAttack(dir);
    }

    // Skill
    if (input.skill && canUseSkill) {
      state = FighterState.skill;
      stateTimer = skillDuration;
      skillCooldownTimer = skillCooldown;
      _executeSkill();
    }
  }

  /// Start an attack, applying hero-specific profile or directional override
  void _startAttack(AttackDirection dir) {
    state = FighterState.attack;
    _attackHit = false;

    // Check for directional attack override
    DirectionalAttack? dirAtk;
    for (final da in directionalAttacks) {
      if (da.direction == dir) { dirAtk = da; break; }
    }

    if (dirAtk != null) {
      // Directional attack
      _currentAttackDamage = attackPower * dirAtk.damage;
      _currentAttackRange = dirAtk.range;
      _currentHitboxHeight = dirAtk.hitboxHeight;
      _currentAttackDuration = dirAtk.duration;
      _currentKnockbackX = dirAtk.knockbackX * (facingRight ? 1 : -1);
      _currentKnockbackY = dirAtk.knockbackY;
      _currentLungeSpeed = 0; // directional attacks don't lunge
      _currentOnHitEffect = dirAtk.onHitEffect;
      _currentEffectDuration = dirAtk.effectDuration;
      stateTimer = _currentAttackDuration;
      velocity.x = 0;
    } else if (normalAttackProfile != null) {
      // Hero-specific normal attack with combo
      final profile = normalAttackProfile!;
      final hitIdx = _comboHitIndex % profile.comboMultipliers.length;
      _currentAttackDamage = profile.getDamageForHit(hitIdx, attackPower);
      _currentAttackRange = profile.range;
      _currentHitboxHeight = fighterHeight * profile.hitboxHeightRatio;
      _currentAttackDuration = profile.duration;
      _currentKnockbackX = profile.knockbackX * (facingRight ? 1 : -1);
      _currentKnockbackY = profile.knockbackY;
      _currentLungeSpeed = profile.lungeSpeed;
      _currentOnHitEffect = OnHitEffect.none;
      _currentEffectDuration = 0;
      stateTimer = _currentAttackDuration;
      velocity.x = (facingRight ? 1 : -1) * _currentLungeSpeed;
      // Advance combo index
      _comboHitIndex = (_comboHitIndex + 1) % profile.maxComboHits;
      _comboResetTimer = _comboResetDelay;
    } else {
      // Default attack
      _currentAttackDamage = attackPower;
      _currentAttackRange = attackRange;
      _currentHitboxHeight = fighterHeight;
      _currentAttackDuration = attackDuration;
      _currentKnockbackX = (facingRight ? 1 : -1) * 200;
      _currentKnockbackY = -100;
      _currentLungeSpeed = 80;
      _currentOnHitEffect = OnHitEffect.none;
      _currentEffectDuration = 0;
      stateTimer = _currentAttackDuration;
      velocity.x = (facingRight ? 1 : -1) * _currentLungeSpeed;
    }
  }

  void _checkAttackHit() {
    if (opponent == null || !opponent!.isAlive) return;
    final attackX = facingRight
        ? position.x + fighterWidth
        : position.x - _currentAttackRange;
    final attackRect = Rect.fromLTWH(
        attackX, position.y, _currentAttackRange, _currentHitboxHeight);
    final opponentRect = Rect.fromLTWH(
        opponent!.position.x, opponent!.position.y,
        fighterWidth, fighterHeight);
    if (attackRect.overlaps(opponentRect)) {
      _attackHit = true;
      final knockback = Vector2(_currentKnockbackX, _currentKnockbackY);
      opponent!.takeDamage(_currentAttackDamage, knockback);
      // Apply on-hit effect
      if (_currentOnHitEffect == OnHitEffect.stun && _currentEffectDuration > 0) {
        opponent!.applyStun(_currentEffectDuration);
      } else if (_currentOnHitEffect == OnHitEffect.freeze && _currentEffectDuration > 0) {
        opponent!.applyFreeze(_currentEffectDuration);
      }
      onAttackHit?.call(opponent!, _currentAttackDamage);
    }
  }

  void _executeSkill() {
    // Delegate to onSkillExecute callback (set by hero data)
  }

  List<Projectile> getSkillProjectiles() {
    if (onSkillExecute != null) {
      return onSkillExecute!(this);
    }
    // Default: simple fireball
    return [
      Projectile(
        owner: this,
        damage: attackPower * 1.5,
        speed: 400,
        direction: Vector2(facingRight ? 1 : -1, 0).normalized(),
        color: color,
        lifetime: 2.0,
        initialPosition: Vector2(
          facingRight ? position.x + fighterWidth + 5 : position.x - 15,
          position.y + fighterHeight * 0.4,
        ),
      ),
    ];
  }

  void takeDamage(double amount, Vector2 knockback) {
    if (!isAlive || isInvincible) return;
    final effectiveDamage = max(1.0, amount - defense);
    hp = max(0, hp - effectiveDamage);
    velocity = knockback.clone();
    state = FighterState.hurt;
    stateTimer = hurtDuration;
    invincibilityTimer = invincibilityDuration;
    hitFlashTimer = hitFlashDuration;
    if (hp <= 0) {
      state = FighterState.dead;
      velocity = Vector2(knockback.x * 0.5, -200);
      _deathTimer = 0;
    }
  }

  void applyStun(double duration) {
    stunTimer = duration;
    state = FighterState.hurt;
    stateTimer = duration;
    SoundManager().playStun();
  }

  void applyFreeze(double duration) {
    freezeTimer = duration;
    velocity = Vector2.zero();
    SoundManager().playFreeze();
  }

  void reset(Vector2 pos) {
    position = pos.clone();
    velocity = Vector2.zero();
    hp = maxHp;
    state = FighterState.idle;
    stateTimer = 0;
    invincibilityTimer = 0;
    stunTimer = 0;
    freezeTimer = 0;
    skillCooldownTimer = 0;
    _comboHitIndex = 0;
    _comboResetTimer = 0;
    _animTimer = 0;
    _deathTimer = 0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final flickerVisible = invincibilityTimer <= 0 ||
        (invincibilityTimer * 10).floor() % 2 == 0;
    if (!flickerVisible) return;

    // Shadow
    final shadowPaint = Paint()..color = const Color(0x33000000);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(fighterWidth / 2, fighterHeight + 5),
        width: fighterWidth * 0.8,
        height: 10,
      ),
      shadowPaint,
    );

    // Death fade-out: apply opacity layer during death animation
    if (state == FighterState.dead && _deathTimer > 0.5) {
      final fadeAlpha = (1.0 - (_deathTimer - 0.5) * 2.0).clamp(0.0, 1.0);
      canvas.saveLayer(
        Rect.fromLTWH(
            -20, -20, fighterWidth + 40, fighterHeight + 40),
        Paint()..color = Color.fromARGB((fadeAlpha * 255).round(), 255, 255, 255),
      );
    }

    // Articulated hero body via HeroRenderer
    final atkProgress = (state == FighterState.attack && _currentAttackDuration > 0)
        ? (stateTimer / _currentAttackDuration).clamp(0.0, 1.0)
        : 0.0;
    // Get hurt timer for recoil animation
    final hurtTimer = (state == FighterState.hurt) ? (stateTimer / hurtDuration).clamp(0.0, 1.0) : 0.0;
    HeroRenderer.render(
      canvas: canvas,
      fighterWidth: fighterWidth,
      fighterHeight: fighterHeight,
      primaryColor: color,
      facingRight: facingRight,
      state: state.name,
      stateTimer: stateTimer,
      visuals: visuals,
      attackProgress: atkProgress,
      velocityX: velocity.x,
      skillVisualType: skillVisualType.name,
      hurtTimer: hurtTimer,
      comboIndex: _comboHitIndex,
      animTimer: _animTimer,
      deathProgress: _deathTimer,
    );

    // Close death fade-out layer
    if (state == FighterState.dead && _deathTimer > 0.5) {
      canvas.restore();
    }

    // Attack hitbox indicator (subtle)
    if (state == FighterState.attack) {
      final atkPaint = Paint()
        ..color = const Color(0x44FFFF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final atkX = facingRight ? fighterWidth : -_currentAttackRange;
      canvas.drawRect(
          Rect.fromLTWH(atkX, 0, _currentAttackRange, _currentHitboxHeight),
          atkPaint);
    }

    // Skill telegraph — hero-specific visual during skill cast
    if (state == FighterState.skill) {
      final progress = (stateTimer / skillDuration).clamp(0.0, 1.0);
      final alpha = (progress * 180).round().clamp(30, 180);
      final cx = fighterWidth / 2;
      final cy = fighterHeight / 2;
      // Extract RGB values once for all skill visuals
      final r = (color.r * 255).round().clamp(0, 255);
      final g = (color.g * 255).round().clamp(0, 255);
      final b = (color.b * 255).round().clamp(0, 255);

      switch (skillVisualType) {
        case SkillVisualType.spin:
          // Expanding ring around fighter
          final radius = skillVisualRadius * (1.0 - progress * 0.3);
          final ringPaint = Paint()
            ..color = Color.fromARGB(alpha, r, g, b)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
          canvas.drawCircle(Offset(cx, cy), radius, ringPaint);
          // Inner glow
          final glowPaint = Paint()
            ..color = Color.fromARGB(alpha ~/ 3, r, g, b);
          canvas.drawCircle(Offset(cx, cy), radius * 0.6, glowPaint);
          // Rotating slash marks
          for (int i = 0; i < 4; i++) {
            final angle = (1.0 - progress) * 12.0 + i * 1.5708; // pi/2
            final sx = cx + cos(angle) * radius * 0.8;
            final sy = cy + sin(angle) * radius * 0.8;
            final ex = cx + cos(angle) * radius;
            final ey = cy + sin(angle) * radius;
            canvas.drawLine(Offset(sx, sy), Offset(ex, ey), ringPaint);
          }

        case SkillVisualType.dash:
          // Directional dash trail + range line
          final dir = facingRight ? 1.0 : -1.0;
          final dashLen = skillVisualDistance * (1.0 - progress * 0.5);
          final startX = facingRight ? fighterWidth : 0.0;
          // Trail rectangle
          final trailPaint = Paint()
            ..color = Color.fromARGB(alpha ~/ 2, r, g, b);
          canvas.drawRect(
            Rect.fromLTWH(
              facingRight ? startX : startX - dashLen,
              fighterHeight * 0.2,
              dashLen,
              fighterHeight * 0.6,
            ),
            trailPaint,
          );
          // Leading edge line
          final edgePaint = Paint()
            ..color = Color.fromARGB(alpha, 255, 255, 255)
            ..strokeWidth = 2;
          final edgeX = startX + dir * dashLen;
          canvas.drawLine(
            Offset(edgeX, fighterHeight * 0.1),
            Offset(edgeX, fighterHeight * 0.9),
            edgePaint,
          );

        case SkillVisualType.fan:
          // Fan/cone indicator showing spread direction
          final fanRadius = 80.0 + skillVisualProjectileCount * 8.0;
          final halfAngle = 0.15 + skillVisualProjectileCount * 0.08; // radians
          final baseAngle = facingRight ? 0.0 : 3.1416; // 0 or pi
          final r = color.red;
          final g = color.green;
          final b = color.blue;
          // Fan arc
          final fanPaint = Paint()
            ..color = Color.fromARGB(alpha ~/ 2, r, g, b);
          final arcRect = Rect.fromCircle(
            center: Offset(facingRight ? fighterWidth : 0, cy),
            radius: fanRadius * (1.0 - progress * 0.3),
          );
          canvas.drawArc(arcRect, baseAngle - halfAngle, halfAngle * 2, true, fanPaint);
          // Fan border
          final borderPaint = Paint()
            ..color = Color.fromARGB(alpha, r, g, b)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawArc(arcRect, baseAngle - halfAngle, halfAngle * 2, true, borderPaint);

        case SkillVisualType.charge:
          // Charge-up glow that intensifies
          final chargeProgress = 1.0 - progress; // 0→1 as charge completes
          final glowRadius = 20.0 + chargeProgress * 30.0;
          final glowAlpha = (chargeProgress * 150).round().clamp(0, 150);
          // Outer glow
          final outerPaint = Paint()
            ..color = Color.fromARGB(glowAlpha ~/ 2, r, g, b);
          canvas.drawCircle(Offset(cx, cy), glowRadius, outerPaint);
          // Inner bright core
          final corePaint = Paint()
            ..color = Color.fromARGB(glowAlpha, 255, 255, 200);
          canvas.drawCircle(Offset(cx, cy), glowRadius * 0.4, corePaint);
          // Charge ring
          final ringPaint = Paint()
            ..color = Color.fromARGB(glowAlpha, r, g, b)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          const startAngle = -1.5708; // -pi/2
          final sweepAngle = chargeProgress * 6.2832; // 2*pi
          canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius),
            startAngle, sweepAngle, false, ringPaint,
          );

        case SkillVisualType.ranged:
          // Simple directional indicator
          final dir = facingRight ? 1.0 : -1.0;
          final startX = facingRight ? fighterWidth : 0.0;
          final linePaint = Paint()
            ..color = Color.fromARGB(alpha, r, g, b)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round;
          // Arrow line
          canvas.drawLine(
            Offset(startX, cy),
            Offset(startX + dir * 60, cy),
            linePaint,
          );
          // Arrowhead
          canvas.drawLine(
            Offset(startX + dir * 60, cy),
            Offset(startX + dir * 48, cy - 8),
            linePaint,
          );
          canvas.drawLine(
            Offset(startX + dir * 60, cy),
            Offset(startX + dir * 48, cy + 8),
            linePaint,
          );
      }
    }

    // Frozen overlay
    if (isFrozen) {
      final freezePaint = Paint()..color = const Color(0x4400CCFF);
      final iceBorder = Paint()
        ..color = const Color(0x8800CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-2, -2, fighterWidth + 4, fighterHeight + 4),
          const Radius.circular(5),
        ),
        freezePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-2, -2, fighterWidth + 4, fighterHeight + 4),
          const Radius.circular(5),
        ),
        iceBorder,
      );
    }

    // Stun stars
    if (isStunned) {
      final starPaint = Paint()..color = const Color(0xFFFFFF00);
      for (int i = 0; i < 3; i++) {
        final angle = (stunTimer * 5 + i * 2.1);
        final sx = fighterWidth / 2 + cos(angle) * 20;
        final sy = -10 + sin(angle) * 5;
        canvas.drawCircle(Offset(sx, sy), 3, starPaint);
      }
    }

    // Name label
    final nameParagraph = _buildText(name, 10, const Color(0xFFFFFFFF));
    canvas.drawParagraph(
      nameParagraph,
      Offset((fighterWidth - nameParagraph.width) / 2, -16),
    );

    // Hit flash overlay
    if (hitFlashTimer > 0) {
      final flashAlpha = (hitFlashTimer / hitFlashDuration).clamp(0.0, 1.0);
      final flashPaint = Paint()
        ..color = Color.fromARGB((flashAlpha * 80).round(), 255, 255, 255);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fighterWidth, fighterHeight),
          const Radius.circular(5),
        ),
        flashPaint,
      );
    }
  }

  Paragraph _buildText(String text, double fontSize, Color color) {
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: fontSize,
    ))
      ..pushStyle(TextStyle(color: color, fontSize: fontSize))
      ..addText(text);
    final paragraph = builder.build();
    paragraph.layout(const ParagraphConstraints(width: 100));
    return paragraph;
  }

  /// Serializable snapshot for rollback netcode.
  /// Includes all mutable state needed to reconstruct a frame.
  Map<String, dynamic> toJson() => {
        'px': position.x,
        'py': position.y,
        'vx': velocity.x,
        'vy': velocity.y,
        'hp': hp,
        'state': state.index,
        'facingRight': facingRight,
        'stateTimer': stateTimer,
        'skillCooldownTimer': skillCooldownTimer,
        'comboHitIndex': _comboHitIndex,
        'comboResetTimer': _comboResetTimer,
        'invincibilityTimer': invincibilityTimer,
        'stunTimer': stunTimer,
        'freezeTimer': freezeTimer,
        'skillVisualType': skillVisualType.index,
        'skillVisualRadius': skillVisualRadius,
        'skillVisualDistance': skillVisualDistance,
        'skillVisualProjectileCount': skillVisualProjectileCount,
        'deathTimer': _deathTimer,
      };

  void fromJson(Map<String, dynamic> data) {
    position.x = (data['px'] as num).toDouble();
    position.y = (data['py'] as num).toDouble();
    velocity.x = (data['vx'] as num).toDouble();
    velocity.y = (data['vy'] as num).toDouble();
    hp = (data['hp'] as num).toDouble();
    state = FighterState.values[data['state'] as int];
    facingRight = data['facingRight'] as bool;
    stateTimer = (data['stateTimer'] as num).toDouble();
    skillCooldownTimer = (data['skillCooldownTimer'] as num?)?.toDouble() ?? 0;
    _comboHitIndex = (data['comboHitIndex'] as num?)?.toInt() ?? 0;
    _comboResetTimer = (data['comboResetTimer'] as num?)?.toDouble() ?? 0;
    invincibilityTimer = (data['invincibilityTimer'] as num?)?.toDouble() ?? 0;
    stunTimer = (data['stunTimer'] as num?)?.toDouble() ?? 0;
    freezeTimer = (data['freezeTimer'] as num?)?.toDouble() ?? 0;
    if (data['skillVisualType'] != null) {
      skillVisualType = SkillVisualType.values[data['skillVisualType'] as int];
    }
    skillVisualRadius = (data['skillVisualRadius'] as num?)?.toDouble() ?? 0;
    skillVisualDistance = (data['skillVisualDistance'] as num?)?.toDouble() ?? 0;
    skillVisualProjectileCount =
        (data['skillVisualProjectileCount'] as num?)?.toInt() ?? 0;
    _deathTimer = (data['deathTimer'] as num?)?.toDouble() ?? 0;
  }
}
