import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'package:flutter/services.dart' show HapticFeedback;

import '../heroes/hero_data.dart';
import '../audio/sound_manager.dart';
import 'projectile.dart';
import '../renderers/fighter_renderer.dart';

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
  static const double deathAnimDuration = 1.2; // 延长死亡动画时间，让倒下过程更明显

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
  bool _prevJump = false; // Edge-triggered jump detection

  // Jump physics
  double _jumpVelocity = 0;
  bool _isGrounded = true;
  static const double _gravity = 800; // pixels/s²

  // Cached Paint for death fade overlay (replaces GPU-heavy saveLayer)
  final Paint _deathFadePaint = Paint()..blendMode = BlendMode.srcOver;

  // Combo tracking
  int _comboHitIndex = 0;
  double _comboResetTimer = 0;
  static const double _comboResetDelay = 0.8;

  // Input buffer for combo chaining (3-5 frames at 30fps)
  bool _attackBuffered = false;
  double _attackBufferTimer = 0;
  static const double _attackBufferWindow = 0.1; // ~3 frames

  // Public combo accessors for HUD
  int get comboHitIndex => _comboHitIndex;
  bool get isInCombo => _comboResetTimer > 0;

  // Animation accessors for FighterRenderer
  double get animTimer => _animTimer;
  double get deathTimer => _deathTimer;
  Paint get deathFadePaint => _deathFadePaint;
  double get currentAttackRange => _currentAttackRange;
  double get currentAttackDuration => _currentAttackDuration;
  double get currentAttackDamage => _currentAttackDamage;
  double get currentHitboxHeight => _currentHitboxHeight;
  bool get isGrounded => _isGrounded;

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
  static const double fighterWidth = 50;
  static const double fighterHeight = 70;
  static const double friction = 800;
  static const double attackRange = 60;
  static const double attackDuration = 0.3;
  static const double hurtDuration = 0.3;
  static const double skillDuration = 0.4;
  static const double invincibilityDuration = 0.5;

  // Screen boundaries - dynamic values will be set in checkStageBoundaries()
  double wrapMinX = 20;      // Left wall position (will be updated from FighterGame)
  double wrapMaxX = 1260;    // Right wall position (will be updated from FighterGame)
  double wrapMinY = 0;       // Top edge of visible area
  double wrapMaxY = 520;     // Ground level (will be updated from FighterGame)

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
    position = initialPosition ?? Vector2(200, 520 - fighterHeight);
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
      // 死亡时不立即清零速度，让角色有自然的倒下效果
      // 先更新速度：重力 + 阻尼（模拟死亡后的惯性）
      velocity.y += gravity * dt;
      velocity.x *= 0.95;
      
      // 再应用速度到位置
      position.x += velocity.x * dt;
      position.y += velocity.y * dt;
      
      // 地面碰撞检测 - 确保角色不会穿透地面
      if (position.y > wrapMaxY - fighterHeight) {
        position.y = wrapMaxY - fighterHeight;
        velocity.y = 0;
      }
      
      // 当速度很小时清零，避免微小抖动
      if (velocity.x.abs() < 5) velocity.x = 0;
      
      input.left = false;
      input.right = false;
      input.up = false;
      input.down = false;
      input.jump = false;
      input.attack = false;
      input.skill = false;
      position.x = position.x.clamp(wrapMinX.toDouble(), (wrapMaxX - fighterWidth).toDouble());
      position.y = position.y.clamp(wrapMinY.toDouble(), (wrapMaxY - fighterHeight).toDouble());
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

    // Input buffer decay
    if (_attackBufferTimer > 0) {
      _attackBufferTimer -= dt;
      if (_attackBufferTimer <= 0) _attackBuffered = false;
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

    // Apply gravity to jump velocity
    if (!_isGrounded) {
      _jumpVelocity += _gravity * dt;
    }

    // Apply velocity (input movement + jump physics)
    position.x += velocity.x * dt;
    position.y += (velocity.y + _jumpVelocity) * dt;

    // Ground detection
    final groundLevel = wrapMaxY - fighterHeight;
    if (position.y >= groundLevel) {
      position.y = groundLevel;
      _jumpVelocity = 0;
      _isGrounded = true;
    }

    // Constrain to stage boundaries (no walking off screen)
    checkStageBoundaries();

    // Hard clamp as safety measure
    position.x = position.x.clamp(wrapMinX.toDouble(), (wrapMaxX - fighterWidth).toDouble());
    position.y = position.y.clamp(wrapMinY.toDouble(), (wrapMaxY - fighterHeight).toDouble());

    // Process input (8-direction movement)
    if (canAct) _processInput();

    // Update facing based on movement direction (not auto-face opponent)
    // This allows players to control which direction they face
    if (state != FighterState.attack && state != FighterState.skill) {
      if (input.left) facingRight = false;
      if (input.right) facingRight = true;
    }

    // Attack hitbox check
    if (state == FighterState.attack && !_attackHit &&
        stateTimer < _currentAttackDuration * 0.5) {
      _checkAttackHit();
    }
  }

  /// Constrain fighter to stage boundaries (no screen wrapping).
  void checkStageBoundaries() {
    // Horizontal: clamp to [wrapMinX, wrapMaxX - fighterWidth]
    // Keep hero fully within visible screen area
    final minX = wrapMinX;
    final maxX = wrapMaxX - fighterWidth;
    if (position.x < minX) {
      position.x = minX;
      if (velocity.x < 0) velocity.x = 0;
    } else if (position.x > maxX) {
      position.x = maxX;
      if (velocity.x > 0) velocity.x = 0;
    }
    // Vertical: clamp to [wrapMinY, wrapMaxY - fighterHeight]
    // Keep hero fully within visible screen area
    final minY = wrapMinY;
    final maxY = wrapMaxY - fighterHeight;
    if (position.y < minY) {
      position.y = minY;
      if (velocity.y < 0) velocity.y = 0;
    } else if (position.y > maxY) {
      position.y = maxY;
      if (velocity.y > 0) velocity.y = 0;
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
    // Dead or cannot act - ignore all input
    if (!canAct) return;

    // 8-direction movement
    double moveX = 0, moveY = 0;
    if (input.left) moveX -= 1;
    if (input.right) moveX += 1;
    if (input.up) moveY -= 1;
    if (input.down) moveY += 1;

    // Jump — impulse applied once per press, only when grounded
    if (input.jump && !_prevJump && _isGrounded) {
      _jumpVelocity = -jumpForce;
      _isGrounded = false;
      SoundManager().playJump();
    }
    _prevJump = input.jump;

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

    // Attack — check for directional attack first, with input buffer
    final wantAttack = input.attack || _attackBuffered;
    if (wantAttack && canAttack) {
      _attackBuffered = false;
      _attackBufferTimer = 0;
      final dir = _getAttackDirection();
      _startAttack(dir);
    } else if (input.attack && !canAttack) {
      // Buffer the attack for combo chaining
      _attackBuffered = true;
      _attackBufferTimer = _attackBufferWindow;
    }

    // Skill
    if (input.skill && canUseSkill) {
      state = FighterState.skill;
      stateTimer = skillDuration;
      skillCooldownTimer = skillCooldown;
      _executeSkill();
      HapticFeedback.heavyImpact();
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
      HapticFeedback.mediumImpact();
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
    // Percentage-based defense: higher defense = damage reduced by a percentage
    // Shield General (38 def) reduces damage to ~57%, Diaochan (18 def) to ~74%
    // Formula: finalDamage = damage * (100 / (100 + defense * 2))
    final reduction = 100.0 / (100.0 + defense * 2.0);
    final effectiveDamage = max(1.0, amount * reduction);
    hp = max(0, hp - effectiveDamage);
    velocity = knockback.clone();
    state = FighterState.hurt;
    HapticFeedback.lightImpact();
    stateTimer = hurtDuration;
    invincibilityTimer = invincibilityDuration;
    hitFlashTimer = hitFlashDuration;
    if (hp <= 0 && state != FighterState.dead) {
      state = FighterState.dead;
      // 不立即清零速度，让角色有自然的倒下效果
      _deathTimer = 0;
      input.left = false;
      input.right = false;
      input.up = false;
      input.down = false;
      input.jump = false;
      input.attack = false;
      input.skill = false;
    }
    position.x = position.x.clamp(wrapMinX.toDouble(), (wrapMaxX - fighterWidth).toDouble());
    position.y = position.y.clamp(wrapMinY.toDouble(), (wrapMaxY - fighterHeight).toDouble());
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
    FighterRenderer.render(canvas, this);
  }

  // --- Serialization support for rollback netcode ---
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
