import 'dart:math';

import '../components/fighter.dart';
import '../utils/game_random.dart';

/// AI difficulty levels
enum AiDifficulty { easy, medium, hard }

/// AI controller for computer-controlled fighters.
///
/// Drives a [Fighter] by setting its input flags each frame.
/// Decision-making uses a lightweight state machine with
/// per-difficulty reaction delays and behavior weights.
class AiController {
  final Fighter fighter;
  final AiDifficulty difficulty;
  final GameRandom _rng;

  // Timing
  double _decisionTimer = 0;
  double _reactionBuffer = 0; // queued action delay

  // Cached decision
  _AiAction _currentAction = _AiAction.idle;

  // Difficulty-tuned parameters
  late final double _reactionDelay;
  late final double _decisionInterval;
  late final double _dodgeChance;
  late final double _skillChance;
  late final double _comboChance;
  late final double _retreatHpThreshold;

  // Distance thresholds
  static const double _meleeRange = 75.0;
  static const double _approachRange = 250.0;
  static const double _tooCloseRange = 40.0;

  AiController({
    required this.fighter,
    this.difficulty = AiDifficulty.medium,
    GameRandom? rng,
  }) : _rng = rng ?? GameRandom() {
    switch (difficulty) {
      case AiDifficulty.easy:
        _reactionDelay = 0.5;
        _decisionInterval = 0.45;
        _dodgeChance = 0.05;
        _skillChance = 0.15;
        _comboChance = 0.0;
        _retreatHpThreshold = 0.15;
      case AiDifficulty.medium:
        _reactionDelay = 0.3;
        _decisionInterval = 0.25;
        _dodgeChance = 0.3;
        _skillChance = 0.5;
        _comboChance = 0.2;
        _retreatHpThreshold = 0.25;
      case AiDifficulty.hard:
        _reactionDelay = 0.1;
        _decisionInterval = 0.12;
        _dodgeChance = 0.65;
        _skillChance = 0.8;
        _comboChance = 0.5;
        _retreatHpThreshold = 0.35;
    }
  }

  /// Call every frame. Sets fighter.input based on AI decisions.
  void update(double dt) {
    if (!fighter.isAlive) {
      _clearInput();
      return;
    }

    // Tick reaction buffer
    if (_reactionBuffer > 0) {
      _reactionBuffer -= dt;
      return;
    }

    // Re-evaluate at interval
    _decisionTimer -= dt;
    if (_decisionTimer <= 0) {
      _decisionTimer = _decisionInterval + _rng.nextDouble() * 0.1;
      _evaluate();
      _reactionBuffer = _reactionDelay * (0.7 + _rng.nextDouble() * 0.6);
    }

    _applyAction();
  }

  // ── Decision logic ──────────────────────────────────────────

  void _evaluate() {
    final opponent = fighter.opponent;
    if (opponent == null || !opponent.isAlive) {
      _currentAction = _AiAction.idle;
      return;
    }

    final dist = _distanceTo(opponent);
    final hpRatio = fighter.hp / fighter.maxHp;
    final oppHpRatio = opponent.hp / opponent.maxHp;
    final skillReady = fighter.canUseSkill;
    final oppAttacking = opponent.state == FighterState.attack ||
        opponent.state == FighterState.skill;

    // Priority 1: dodge opponent attack if close
    if (oppAttacking && dist < _meleeRange * 1.5) {
      if (_rng.nextDouble() < _dodgeChance) {
        _currentAction = _rng.nextBool() ? _AiAction.dodgeUp : _AiAction.retreat;
        return;
      }
    }

    // Priority 2: retreat when low HP (unless opponent is even lower)
    if (hpRatio < _retreatHpThreshold && oppHpRatio > hpRatio) {
      if (skillReady && _rng.nextDouble() < _comboChance) {
        _currentAction = _AiAction.useSkill;
        return;
      }
      _currentAction = _AiAction.retreat;
      return;
    }

    // Priority 3: go aggressive when opponent HP is low
    if (oppHpRatio < 0.2 && dist < _approachRange) {
      _currentAction = dist < _meleeRange ? _AiAction.attack : _AiAction.approach;
      return;
    }

    // Priority 4: combo attack + skill (hard AI)
    if (dist < _meleeRange && skillReady && _rng.nextDouble() < _comboChance) {
      _currentAction = _AiAction.comboAttackSkill;
      return;
    }

    // Priority 5: melee attack when in range
    if (dist < _meleeRange && fighter.canAttack) {
      _currentAction = _AiAction.attack;
      return;
    }

    // Priority 6: use skill at medium range
    if (skillReady && dist < _approachRange && _rng.nextDouble() < _skillChance) {
      _currentAction = _AiAction.useSkill;
      return;
    }

    // Priority 6: approach when far
    if (dist > _meleeRange) {
      // Occasionally hover-approach from above for variety
      if (dist > _approachRange && _rng.nextDouble() < 0.2) {
        _currentAction = _AiAction.hoverApproach;
        return;
      }
      _currentAction = _AiAction.approach;
      return;
    }

    // Priority 7: back off if too close (avoid clipping)
    if (dist < _tooCloseRange) {
      _currentAction = _rng.nextDouble() < 0.5 ? _AiAction.attack : _AiAction.retreat;
      return;
    }

    _currentAction = _AiAction.idle;
  }

  // ── Input application ───────────────────────────────────────

  void _applyAction() {
    _clearInput();
    final opponent = fighter.opponent;
    if (opponent == null) return;

    final toRight = opponent.position.x > fighter.position.x;
    final toBottom = opponent.position.y > fighter.position.y;

    switch (_currentAction) {
      case _AiAction.idle:
        break;
      case _AiAction.approach:
        _moveToward(toRight);
        // Also move vertically toward opponent
        _moveVertToward(toBottom);
      case _AiAction.retreat:
        _moveToward(!toRight);
      case _AiAction.attack:
        fighter.input.attack = true;
      case _AiAction.useSkill:
        fighter.input.skill = true;
      case _AiAction.dodgeUp:
        _moveToward(!toRight);
        _moveVertToward(false); // move up to dodge
      case _AiAction.hoverApproach:
        _moveToward(toRight);
        _moveVertToward(false); // approach from above
      case _AiAction.comboAttackSkill:
        fighter.input.attack = true;
        fighter.input.skill = true;
    }
  }

  void _moveToward(bool right) {
    if (right) {
      fighter.input.right = true;
    } else {
      fighter.input.left = true;
    }
  }

  void _moveVertToward(bool down) {
    if (down) {
      fighter.input.down = true;
    } else {
      fighter.input.up = true;
    }
  }

  void _clearInput() {
    fighter.input
      ..left = false
      ..right = false
      ..up = false
      ..down = false
      ..attack = false
      ..skill = false;
  }

  double _distanceTo(Fighter other) {
    return (fighter.position - other.position).length;
  }
}

/// Internal action enum for AI state machine.
enum _AiAction {
  idle,
  approach,
  retreat,
  attack,
  useSkill,
  dodgeUp,
  hoverApproach,
  comboAttackSkill,
}
