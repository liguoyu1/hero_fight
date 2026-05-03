import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Alignment, LinearGradient;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import 'components/fighter.dart';
import 'components/projectile.dart';
import 'components/touch_controls.dart';
import 'components/effects.dart';
import 'components/particle_system.dart';
import 'components/debug_overlay.dart';
import 'components/tutorial_overlay.dart';
import '../game/audio/sound_manager.dart';
import '../i18n/app_localizations.dart';
import 'network/rollback_engine.dart';
import 'utils/game_random.dart';
import 'heroes/hero_data.dart';
import 'heroes/hero_registry.dart';
import 'heroes/skill_util.dart';

/// Game states
enum GameState { menu, heroSelect, fighting, paused, result }

/// Main Flame game class for Hero Fighter
class FighterGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents {
  // Game state
  GameState gameState = GameState.fighting;
  double roundTimer = 99;
  String? winnerName;

  // Fighters
  late Fighter player1;
  late Fighter player2;

  // Hero data (injected)
  final String hero1Id;
  final String hero2Id;
  final String mode; // 'ai', 'local', 'online', 'lan'

  // Projectiles
  final List<Projectile> projectiles = [];

  // Touch controls (mobile)
  TouchControls? touchControls;

  // External callback for AI updates
  void Function(double dt)? onExternalUpdate;

  // Callback when game state changes (for saving records)
  void Function(GameState newState)? onGameStateChanged;

  // Network remote input storage (for online/lan mode)
  final FighterInput _remoteInput = FighterInput();
  bool _hasRemoteInput = false;
  int localPlayerIndex = 0; // 0 or 1, which player this device controls

  // VFX
  final ScreenShake screenShake = ScreenShake();
  late ParticleSystem particleSystem;
  late DebugOverlay debugOverlay;
  final TutorialOverlay tutorialOverlay = TutorialOverlay();
  RollbackEngine? rollbackEngine;

  // Smooth HP bar interpolation
  double _displayHp1 = 0;
  double _displayHp2 = 0;
  static const double _hpLerpSpeed = 5.0; // units per second multiplier

  // Fixed timestep for deterministic rollback support
  static const double tickDt = 1.0 / 30.0;
  double _accumulator = 0;

  // Deterministic random number generator (seed shared across all systems)
  final GameRandom gameRandom = GameRandom();

  /// Apply seed from server — both clients MUST use the same seed for determinism.
  void applyRollbackSeed(int seed) => gameRandom.state = seed;

  /// Frames to run prediction before accepting player input.
  /// Lets both clients fill their rollback buffers before real gameplay starts.
  int predictionFrames = 0;

  // Combo counter display state
  double _comboDisplayTimer1 = 0;
  double _comboDisplayTimer2 = 0;
  int _comboDisplayCount1 = 0;
  int _comboDisplayCount2 = 0;
  int _lastComboIndex1 = 0;
  int _lastComboIndex2 = 0;

  // Keyboard state tracking
  final Set<LogicalKeyboardKey> _keysPressed = {};

  // Stage constants (for background rendering only — no collision)
  static const double groundY = 520;
  static const double wallLeft = 20;
  static const double wallRight = 1260;
  static const double stageWidth = 1280;
  static const double stageHeight = 600;
  // Game world aspect ratio
  static const double gameAspectRatio = stageWidth / stageHeight; // 2.133...

  FighterGame({
    required this.hero1Id,
    required this.hero2Id,
    this.mode = 'ai',
  });

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  @override
  Future<void> onLoad() async {
    try {
      await super.onLoad();
    } catch (e) {
      // Continue even if super.onLoad fails
    }

    final registry = HeroRegistry.instance;
    final hero1 = registry.get(hero1Id);
    final hero2 = registry.get(hero2Id);

    // Create fighters with hero data
    player1 = _createFighter(hero1, 0);
    player2 = _createFighter(hero2, 1);

    player1.opponent = player2;
    player2.opponent = player1;

    // Initialize smooth HP display
    _displayHp1 = player1.hp;
    _displayHp2 = player2.hp;

    add(player1);
    add(player2);

    // Particle system for VFX
    particleSystem = ParticleSystem(rng: gameRandom);
    add(particleSystem);

    // Inject deterministic PRNG for screen shake (rollback netcode)
    screenShake.random = gameRandom;

    // Debug overlay (toggle with backtick key)
    debugOverlay = DebugOverlay();
    add(debugOverlay);

    // Tutorial overlay (first-time onboarding) — add to viewport for screen-space tap handling
    camera.viewport.add(tutorialOverlay);
    tutorialOverlay.checkAndShow();

    // In AI mode, attach AI controller to player2
    if (mode == 'ai') {
      _setupAi();
    }

    // Add touch controls on mobile/web — added to viewport so they're in screen space
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      touchControls = TouchControls();
      camera.viewport.add(touchControls!);
    }

    // Set camera to fixed resolution, anchored at center of stage
    camera.viewfinder.visibleGameSize = Vector2(stageWidth, stageHeight);
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(stageWidth / 2, stageHeight / 2);

    // Initialize sounds
    try {
      await SoundManager().init();
      SoundManager().playRoundStart();
    } catch (_) {
      // Audio is non-critical
    }
  }

  Fighter _createFighter(HeroData? hero, int index) {
    final defaultName = index == 0 ? 'Player 1' : 'Player 2';
    final defaultColor = index == 0 ? const Color(0xFF4488FF) : const Color(0xFFFF4444);
    final defaultPos = index == 0
        ? Vector2(200, 250)
        : Vector2(1000, 250);

    if (hero == null) {
      return Fighter(
        playerIndex: index,
        name: defaultName,
        color: defaultColor,
        initialPosition: defaultPos,
      );
    }

    final fighter = Fighter(
      playerIndex: index,
      name: hero.name,
      heroId: hero.id,
      color: hero.color,
      maxHp: hero.hp,
      speed: hero.speed,
      jumpForce: hero.jumpForce,
      attackPower: hero.attackPower,
      defense: hero.defense,
      skillCooldown: hero.skillCooldown,
      initialPosition: defaultPos,
      normalAttackProfile: hero.normalAttack,
      directionalAttacks: hero.directionalAttacks,
      visuals: hero.visuals,
      onAttackHit: _spawnHitVfx,
      onSkillExecute: (owner) {
        final result = hero.executeSkill(
          posX: owner.position.x,
          posY: owner.position.y,
          facingRight: owner.facingRight,
        );

        // Configure hero-specific skill visual presentation
        final skillVisual = _classifySkillVisual(result);
        owner.skillVisualType = skillVisual;
        owner.skillVisualRadius = result.spinRadius;
        owner.skillVisualDistance = result.dashDistance;
        owner.skillVisualProjectileCount = result.projectiles.length;

        return applySkillEffect(result, owner);
      },
    );

    return fighter;
  }

  /// Classify a hero's skill into a visual archetype based on SkillResult data.
  SkillVisualType _classifySkillVisual(SkillResult result) {
    if (result.spinAttack && result.spinRadius > 0) {
      return SkillVisualType.spin;
    }
    if (result.dashForward && result.dashDistance > 0) {
      return SkillVisualType.dash;
    }
    if (result.chargeTime > 0) {
      return SkillVisualType.charge;
    }
    if (result.projectiles.length >= 4) {
      return SkillVisualType.fan;
    }
    return SkillVisualType.ranged;
  }

  void _setupAi() {
    // AI controller will be created by an external wrapper
    // The game screen handles AI updates
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    touchControls?.onGameResize(size);
    tutorialOverlay.onGameResize(size);

    // 使用固定游戏世界大小，让 Flame 自动缩放适应屏幕
    camera.viewfinder.visibleGameSize = Vector2(stageWidth.toDouble(), stageHeight.toDouble());
  }

  @override
  void update(double dt) {
    // Tutorial overlay pauses game logic — viewport still auto-updates/renders
    if (tutorialOverlay.isVisible) {
      super.update(dt);
      return;
    }

    if (gameState != GameState.fighting) {
      super.update(dt);
      return;
    }

    // Fixed-timestep accumulator for deterministic simulation (Rollback R1)
    _accumulator += dt;
    // Cap accumulator to avoid spiral of death (max 6 frames behind)
    if (_accumulator > 0.2) _accumulator = 0.2;
    while (_accumulator >= tickDt) {
      _accumulator -= tickDt;
      _fixedUpdate(tickDt);
    }
  }

  /// Fixed-step game logic update — one tick (1/30s).
  /// All deterministic simulation runs here for rollback compatibility.
  void _fixedUpdate(double dt) {
    // Round timer
    roundTimer -= dt;
    if (roundTimer <= 0) {
      roundTimer = 0;
      _endRound();
      super.update(dt);
      return;
    }

    // --- Rollback engine path: engine manages inputs + frame tracking ---
    if (rollbackEngine != null) {
      _fixedUpdateRollback(dt);
      return;
    }

    // --- Original path: direct keyboard/touch + AI ---

    // Apply keyboard input to fighters
    _applyKeyboardInput();

    // Apply touch input to P1
    if (touchControls != null) {
      _applyTouchInput();
    }

    // Drive AI from external callback
    onExternalUpdate?.call(dt);

    super.update(dt);

    // Handle skill projectile spawning
    _checkSkillProjectiles(player1);
    _checkSkillProjectiles(player2);

    // Update projectiles and check collisions
    _updateProjectiles(dt);

    // Handle on-hit effects (freeze, stun from projectile configs)
    _applyOnHitEffects(dt);

    // Camera follows midpoint
    _updateCamera();

    // Check win condition
    if (!player1.isAlive || !player2.isAlive) {
      _endRound();
    }

    // VFX updates
    screenShake.update(dt);

    // Smooth HP interpolation
    _displayHp1 += (player1.hp - _displayHp1) * _hpLerpSpeed * dt;
    _displayHp2 += (player2.hp - _displayHp2) * _hpLerpSpeed * dt;
    // Snap when very close
    if ((_displayHp1 - player1.hp).abs() < 0.5) _displayHp1 = player1.hp;
    if ((_displayHp2 - player2.hp).abs() < 0.5) _displayHp2 = player2.hp;

    // Combo counter tracking
    _comboDisplayTimer1 -= dt;
    _comboDisplayTimer2 -= dt;
    if (player1.isInCombo && player1.comboHitIndex != _lastComboIndex1) {
      _comboDisplayCount1 = player1.comboHitIndex;
      _comboDisplayTimer1 = 1.5;
      _lastComboIndex1 = player1.comboHitIndex;
    }
    if (player2.isInCombo && player2.comboHitIndex != _lastComboIndex2) {
      _comboDisplayCount2 = player2.comboHitIndex;
      _comboDisplayTimer2 = 1.5;
      _lastComboIndex2 = player2.comboHitIndex;
    }
    if (!player1.isInCombo) { _lastComboIndex1 = 0; }
    if (!player2.isInCombo) { _lastComboIndex2 = 0; }
  }

  /// Rollback-engine-driven fixed update: engine manages inputs + snapshots.
  void _fixedUpdateRollback(double dt) {
    final engine = rollbackEngine!;

    // --- Prediction phase: run N frames silently to sync rollback buffers ---
    final bool inPrediction = predictionFrames > 0;
    if (inPrediction) {
      predictionFrames--;
    }

    // Collect local input and feed to engine (frame++, save input, predict remote)
    final localInput = _collectP1Input();
    engine.beforeFrame(localInput);

    // Drive fighters from engine's buffered inputs
    player1.input.copyFrom(engine.localInput);
    if (engine.hasRemoteInput) {
      player2.input.copyFrom(engine.remoteInput);
    }

    // Core simulation
    super.update(dt);
    _checkSkillProjectiles(player1);
    _checkSkillProjectiles(player2);
    _updateProjectiles(dt);
    _applyOnHitEffects(dt);
    _updateCamera();

    if (!player1.isAlive || !player2.isAlive) {
      if (!inPrediction) _endRound();
    }

    // VFX (still rendered on screen, but not replayed during rollback)
    screenShake.update(dt);

    // Smooth HP interpolation
    _displayHp1 += (player1.hp - _displayHp1) * _hpLerpSpeed * dt;
    _displayHp2 += (player2.hp - _displayHp2) * _hpLerpSpeed * dt;
    if ((_displayHp1 - player1.hp).abs() < 0.5) _displayHp1 = player1.hp;
    if ((_displayHp2 - player2.hp).abs() < 0.5) _displayHp2 = player2.hp;

    // Combo counter tracking
    _comboDisplayTimer1 -= dt;
    _comboDisplayTimer2 -= dt;
    if (player1.isInCombo && player1.comboHitIndex != _lastComboIndex1) {
      _comboDisplayCount1 = player1.comboHitIndex;
      _comboDisplayTimer1 = 1.5;
      _lastComboIndex1 = player1.comboHitIndex;
    }
    if (player2.isInCombo && player2.comboHitIndex != _lastComboIndex2) {
      _comboDisplayCount2 = player2.comboHitIndex;
      _comboDisplayTimer2 = 1.5;
      _lastComboIndex2 = player2.comboHitIndex;
    }
    if (!player1.isInCombo) { _lastComboIndex1 = 0; }
    if (!player2.isInCombo) { _lastComboIndex2 = 0; }

    // Engine post-processing (snapshot, etc.)
    engine.afterFrame();
  }

  /// Collect P1's input from keyboard + touch controls.
  FighterInput _collectP1Input() {
    final input = FighterInput.empty();

    if (localPlayerIndex == 0) {
      // P1: WASD + J/K
      input.left = _keysPressed.contains(LogicalKeyboardKey.keyA);
      input.right = _keysPressed.contains(LogicalKeyboardKey.keyD);
      input.up = _keysPressed.contains(LogicalKeyboardKey.keyW);
      input.down = _keysPressed.contains(LogicalKeyboardKey.keyS);
      input.attack = _keysPressed.contains(LogicalKeyboardKey.keyJ);
      input.skill = _keysPressed.contains(LogicalKeyboardKey.keyK);
    } else {
      // P2: Arrow keys + Numpad 1/2
      input.left = _keysPressed.contains(LogicalKeyboardKey.arrowLeft);
      input.right = _keysPressed.contains(LogicalKeyboardKey.arrowRight);
      input.up = _keysPressed.contains(LogicalKeyboardKey.arrowUp);
      input.down = _keysPressed.contains(LogicalKeyboardKey.arrowDown);
      input.attack = _keysPressed.contains(LogicalKeyboardKey.numpad1);
      input.skill = _keysPressed.contains(LogicalKeyboardKey.numpad2);
    }

    // Touch overrides for P1 only
    if (localPlayerIndex == 0 && touchControls != null) {
      final ti = touchControls!.input;
      if (ti.left || ti.right || ti.attack || ti.skill) {
        input.left = ti.left;
        input.right = ti.right;
        if (ti.jump) input.up = true;
        input.attack = ti.attack;
        input.skill = ti.skill;
      }
    }

    return input;
  }

  /// Receive remote player's input from the network.
  ///
  /// Called by [NetworkManager]/GameScreen when remote input packets arrive.
  /// [frame] is the game frame this input was generated for.
  /// [input] contains the 7 bool flags from the remote player.
  void receiveRemoteInput(int frame, FighterInput input) {
    rollbackEngine?.receiveRemote(frame, input);
  }

  /// Re-simulate one tick of core game logic (no input reading, no rendering).
  ///
  /// Used by [RollbackEngine] during rollback to re-compute state after
  /// restoring from a snapshot. Inputs must be set on [player1.input] and
  /// [player2.input] BEFORE calling this method.
  ///
  /// Only runs deterministic simulation: physics, projectiles, collisions,
  /// round timer, win condition. Skips keyboard/touch input reading, AI
  /// callbacks, camera, HP interpolation, combo display, screen shake.
  void resimulateTick() {
    const dt = tickDt;

    // Round timer
    roundTimer -= dt;
    if (roundTimer <= 0) {
      roundTimer = 0;
      _endRound();
      return;
    }

    // Flame physics + collision detection + fighter state machines
    super.update(dt);

    // Skill projectiles
    _checkSkillProjectiles(player1);
    _checkSkillProjectiles(player2);

    // Projectile movement + collision + cleanup
    _updateProjectiles(dt);

    // Win condition
    if (!player1.isAlive || !player2.isAlive) {
      _endRound();
    }
  }

  void _checkSkillProjectiles(Fighter fighter) {
    if (fighter.state == FighterState.skill &&
        fighter.stateTimer > Fighter.skillDuration * 0.3 &&
        fighter.stateTimer < Fighter.skillDuration * 0.7) {
      final newProjectiles = fighter.getSkillProjectiles();
      for (final p in newProjectiles) {
        projectiles.add(p);
        add(p);
      }
      // Skill sound with hero pitch
      SoundManager().playSkill(heroId: fighter.heroId);
    }
  }

  void _updateProjectiles(double dt) {
    // Check projectile-fighter collisions
    for (final p in projectiles) {
      if (p.expired) continue;

      bool hit = false;
      if (p.owner != player1) {
        if (p.checkHit(player1)) hit = true;
      }
      if (p.owner != player2) {
        if (p.checkHit(player2)) hit = true;
      }

      if (hit) {
        // Spawn damage number at the hit target's position
        final target = (p.owner != player1) ? player1 : player2;
        _spawnHitVfx(target, p.damage);
      }
    }
    // Remove expired
    projectiles.removeWhere((p) {
      if (p.expired) {
        p.removeFromParent();
        return true;
      }
      return false;
    });
  }

  /// Apply on-hit effects (freeze, stun) from projectiles that hit
  void _applyOnHitEffects(double dt) {
    // Handled inside checkHit — this is a placeholder for future expansion
  }

  void _updateCamera() {
    // Camera is fixed at stage center — HUD is drawn in world coords at fixed positions
    // Only apply screen shake offset
    camera.viewfinder.position = Vector2(
      stageWidth / 2 + screenShake.currentOffset.x,
      stageHeight / 2 + screenShake.currentOffset.y,
    );
  }

  void _endRound() {
    gameState = GameState.result;
    final l10n = AppLocalizations.fromSystemLocale();
    if (!player1.isAlive && !player2.isAlive) {
      winnerName = l10n.draw;
    } else if (!player2.isAlive) {
      winnerName = player1.name;
    } else if (!player1.isAlive) {
      winnerName = player2.name;
    } else {
      // Timer expired — higher HP wins
      if (player1.hp > player2.hp) {
        winnerName = player1.name;
      } else if (player2.hp > player1.hp) {
        winnerName = player2.name;
      } else {
        winnerName = l10n.draw;
      }
    }
    SoundManager().playWin();
    
    // Notify listeners that game state changed
    onGameStateChanged?.call(gameState);
  }

  void resetRound() {
    player1.reset(Vector2(200, 250));
    player2.reset(Vector2(1000, 250));
    for (final p in projectiles) {
      p.removeFromParent();
    }
    projectiles.clear();
    roundTimer = 99;
    winnerName = null;
    gameState = GameState.fighting;
  }

  /// Spawn a projectile into the game world
  void spawnProjectile(Projectile p) {
    projectiles.add(p);
    add(p);
  }

  // --- VFX helpers ---

  void _spawnHitVfx(Fighter target, double damage) {
    final dmgNum = DamageNumber(
      damage: damage,
      color: const Color(0xFFFFDD44),
      position: Vector2(
        target.position.x + Fighter.fighterWidth / 2,
        target.position.y - 10,
      ),
    );
    add(dmgNum);
    final shakeIntensity = (damage / 300).clamp(0.1, 0.6);
    screenShake.addTrauma(shakeIntensity);

    // Hit spark particles
    particleSystem.spawnHitSparks(
      target.position.x + Fighter.fighterWidth / 2,
      target.position.y + Fighter.fighterHeight / 2,
      target.color,
    );

    // Determine attacker for hero-specific pitch
    final attacker = (target == player1) ? player2 : player1;
    final attackerHeroId = attacker.heroId;

    // Sound — choose hit type based on damage magnitude
    final sound = SoundManager();
    if (damage >= 80) {
      sound.playComboFinisher(heroId: attackerHeroId);
    } else if (damage >= 40) {
      sound.playHeavyHit(heroId: attackerHeroId);
    } else {
      sound.playLightHit(heroId: attackerHeroId);
    }
    sound.playHurt(heroId: target.heroId);
    if (!target.isAlive) {
      sound.playDeath();
    }
  }

  /// Set remote player's input received via network (online/lan mode)
  void setNetworkInput({
    required bool left,
    required bool right,
    bool up = false,
    bool down = false,
    required bool jump,
    required bool attack,
    required bool skill,
    int frame = 0,
  }) {
    _remoteInput.left = left;
    _remoteInput.right = right;
    _remoteInput.up = up;
    _remoteInput.down = down;
    _remoteInput.jump = jump;
    _remoteInput.attack = attack;
    _remoteInput.skill = skill;
    _hasRemoteInput = true;
  }

  /// Get local keyboard input as a map for network sending
  Map<String, dynamic> getLocalInput(int localPlayerIndex) {
    if (localPlayerIndex == 0) {
      return {
        'left': _keysPressed.contains(LogicalKeyboardKey.keyA),
        'right': _keysPressed.contains(LogicalKeyboardKey.keyD),
        'up': _keysPressed.contains(LogicalKeyboardKey.keyW),
        'down': _keysPressed.contains(LogicalKeyboardKey.keyS),
        'jump': false, // jump deprecated for 8-direction
        'attack': _keysPressed.contains(LogicalKeyboardKey.keyJ),
        'skill': _keysPressed.contains(LogicalKeyboardKey.keyK),
      };
    } else {
      return {
        'left': _keysPressed.contains(LogicalKeyboardKey.arrowLeft),
        'right': _keysPressed.contains(LogicalKeyboardKey.arrowRight),
        'up': _keysPressed.contains(LogicalKeyboardKey.arrowUp),
        'down': _keysPressed.contains(LogicalKeyboardKey.arrowDown),
        'jump': false, // jump deprecated for 8-direction
        'attack': _keysPressed.contains(LogicalKeyboardKey.numpad1),
        'skill': _keysPressed.contains(LogicalKeyboardKey.numpad2),
      };
    }
  }

  // --- Input Handling ---

  void _applyKeyboardInput() {
    if (mode == 'online' || mode == 'lan') {
      // Network mode: this device only controls its assigned player
      // The player's slot is set by localPlayerIndex
      // P1 (slot 0) uses WASD+J/K locally
      // P2 (slot 1) uses arrow keys locally
      if (localPlayerIndex == 0) {
        player1.input.left = _keysPressed.contains(LogicalKeyboardKey.keyA);
        player1.input.right = _keysPressed.contains(LogicalKeyboardKey.keyD);
        player1.input.up = _keysPressed.contains(LogicalKeyboardKey.keyW);
        player1.input.down = _keysPressed.contains(LogicalKeyboardKey.keyS);
        player1.input.jump = false; // jump deprecated for 8-direction
        player1.input.attack = _keysPressed.contains(LogicalKeyboardKey.keyJ);
        player1.input.skill = _keysPressed.contains(LogicalKeyboardKey.keyK);
        // Opponent (P2) gets remote input
        if (_hasRemoteInput) {
          player2.input.left = _remoteInput.left;
          player2.input.right = _remoteInput.right;
          player2.input.up = _remoteInput.up;
          player2.input.down = _remoteInput.down;
          player2.input.jump = _remoteInput.jump;
          player2.input.attack = _remoteInput.attack;
          player2.input.skill = _remoteInput.skill;
        }
      } else {
        player2.input.left = _keysPressed.contains(LogicalKeyboardKey.arrowLeft);
        player2.input.right = _keysPressed.contains(LogicalKeyboardKey.arrowRight);
        player2.input.up = _keysPressed.contains(LogicalKeyboardKey.arrowUp);
        player2.input.down = _keysPressed.contains(LogicalKeyboardKey.arrowDown);
        player2.input.jump = false; // jump deprecated for 8-direction
        player2.input.attack = _keysPressed.contains(LogicalKeyboardKey.numpad1);
        player2.input.skill = _keysPressed.contains(LogicalKeyboardKey.numpad2);
        // Opponent (P1) gets remote input
        if (_hasRemoteInput) {
          player1.input.left = _remoteInput.left;
          player1.input.right = _remoteInput.right;
          player1.input.up = _remoteInput.up;
          player1.input.down = _remoteInput.down;
          player1.input.jump = _remoteInput.jump;
          player1.input.attack = _remoteInput.attack;
          player1.input.skill = _remoteInput.skill;
        }
      }
      return;
    }

    // Player 1: WASD + JKL (for ai/local mode)
    player1.input.left = _keysPressed.contains(LogicalKeyboardKey.keyA);
    player1.input.right = _keysPressed.contains(LogicalKeyboardKey.keyD);
    player1.input.up = _keysPressed.contains(LogicalKeyboardKey.keyW);
    player1.input.down = _keysPressed.contains(LogicalKeyboardKey.keyS);
    player1.input.jump = false; // jump deprecated for 8-direction
    player1.input.attack = _keysPressed.contains(LogicalKeyboardKey.keyJ);
    player1.input.skill = _keysPressed.contains(LogicalKeyboardKey.keyK);

    // Player 2: Arrow keys (only in local mode, not AI)
    if (mode == 'local') {
      player2.input.left = _keysPressed.contains(LogicalKeyboardKey.arrowLeft);
      player2.input.right = _keysPressed.contains(LogicalKeyboardKey.arrowRight);
      player2.input.up = _keysPressed.contains(LogicalKeyboardKey.arrowUp);
      player2.input.down = _keysPressed.contains(LogicalKeyboardKey.arrowDown);
      player2.input.jump = false;
      player2.input.attack = _keysPressed.contains(LogicalKeyboardKey.numpad1);
      player2.input.skill = _keysPressed.contains(LogicalKeyboardKey.numpad2);
    }
  }

  void _applyTouchInput() {
    if (touchControls == null) return;
    final ti = touchControls!.input;
    // Touch overrides keyboard for P1
    if (ti.left || ti.right || ti.jump || ti.attack || ti.skill) {
      player1.input.left = ti.left;
      player1.input.right = ti.right;
      player1.input.jump = ti.jump;
      player1.input.attack = ti.attack;
      player1.input.skill = ti.skill;
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysPressed.clear();
    _keysPressed.addAll(keysPressed);

    // Tutorial overlay intercepts all input when visible
    if (tutorialOverlay.isVisible && event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        tutorialOverlay.skip();
      } else {
        tutorialOverlay.advance();
      }
      return KeyEventResult.handled;
    }

    // Escape to pause/unpause
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (gameState == GameState.fighting) {
        gameState = GameState.paused;
      } else if (gameState == GameState.paused) {
        gameState = GameState.fighting;
      }
      return KeyEventResult.handled;
    }

    // Backtick to toggle debug overlay
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backquote) {
      debugOverlay.toggle();
      return KeyEventResult.handled;
    }

    // Enter to restart after result
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (gameState == GameState.result) {
        resetRound();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.handled;
  }

  // --- Rendering: Stage + HUD ---

  @override
  void render(Canvas canvas) {
    // Background gradient
    final bgRect = Rect.fromLTWH(0, 0, stageWidth, stageHeight);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0D0D2B), Color(0xFF1A1A3E), Color(0xFF2A1A1A)],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Ground
    final groundPaint = Paint()..color = const Color(0xFF3A3A3A);
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, stageWidth, stageHeight - groundY),
      groundPaint,
    );
    // Ground line
    final linePaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, groundY), Offset(stageWidth, groundY), linePaint);

    // Walls
    final wallPaint = Paint()..color = const Color(0xFF555555);
    canvas.drawRect(Rect.fromLTWH(0, 0, wallLeft, stageHeight), wallPaint);
    canvas.drawRect(Rect.fromLTWH(wallRight, 0, stageWidth - wallRight, stageHeight), wallPaint);

    // Render game components (fighters, projectiles, touch controls)
    super.render(canvas);

    // HUD overlay
    _renderHUD(canvas);

    // Pause overlay
    if (gameState == GameState.paused) {
      _renderOverlay(canvas, 'PAUSED', 'Press ESC to resume');
    }

    // Result overlay
    if (gameState == GameState.result) {
      final l10n = AppLocalizations.fromSystemLocale();
      final msg = winnerName == l10n.draw ? '${l10n.draw}!' : '${winnerName ?? ""} ${l10n.wins}!';
      _renderOverlay(canvas, msg, 'Press ENTER to restart');
    }

    // Viewport handles tutorial overlay rendering automatically
  }

  void _renderHUD(Canvas canvas) {
    final registry = HeroRegistry.instance;
    final h1 = registry.get(player1.heroId);
    final h2 = registry.get(player2.heroId);

    // 使用固定游戏世界大小，确保 HUD 始终在可见区域内
    const marginX = stageWidth * 0.03; // 3% of game width
    const marginY = stageHeight * 0.03; // 3% of game height
    
    // HUD 元素大小基于固定游戏世界
    const barWidth = 300.0;
    const barHeight = 20.0;
    const barY = marginY;
    const textSize = 28.0;
    const infoTextSize = 14.0;

    // P1 HP bar (left side) — uses smooth display HP
    _drawHPBar(canvas, marginX, barY, barWidth, barHeight,
        player1.hp, _displayHp1, player1.maxHp, player1.color, textSize: textSize);

    // P2 HP bar (right side, fills from right) — uses smooth display HP
    _drawHPBar(canvas, stageWidth - marginX - barWidth, barY, barWidth, barHeight,
        player2.hp, _displayHp2, player2.maxHp, player2.color, rightAligned: true, textSize: textSize);

    // Timer (centered)
    final timerText = roundTimer.ceil().toString().padLeft(2, '0');
    final timerParagraph = _buildText(timerText, textSize, const Color(0xFFFFFFFF));
    canvas.drawParagraph(timerParagraph, Offset(stageWidth / 2 - timerParagraph.width / 2, marginY * 0.5));

    // Player info blocks (below HP bars)
    final infoY = barY + barHeight + marginY * 0.5;
    _drawPlayerInfo(canvas, marginX, infoY, player1, h1, true, infoTextSize);
    _drawPlayerInfo(canvas, stageWidth - marginX - 200, infoY, player2, h2, false, infoTextSize);

    // Combo counters (rendered near each fighter)
    _drawComboCounter(canvas, player1, _comboDisplayCount1, _comboDisplayTimer1);
    _drawComboCounter(canvas, player2, _comboDisplayCount2, _comboDisplayTimer2);
  }

  void _drawPlayerInfo(Canvas canvas, double x, double y, Fighter fighter, HeroData? hero, bool leftAligned, double textSize) {
    // Scale based on textSize
    final l10n = AppLocalizations.fromSystemLocale();
    final titleSize = textSize * 0.9;
    final skillSize = textSize * 0.85;
    final infoWidth = 200 * (textSize / 14); // Scale width with text size
    
    // Hero name + title
    final titleText = hero != null ? '${hero.name} · ${hero.title}' : fighter.name;
    final titleP = _buildText(titleText, titleSize, fighter.color.withValues(alpha: 0.9));
    canvas.drawParagraph(
      titleP,
      Offset(leftAligned ? x : x + infoWidth - titleP.width, y),
    );

    // Skill info
    final skillName = hero != null ? '[K] ${hero.skillName}' : '[K] Skill';
    final skillReady = fighter.skillCooldownTimer <= 0;
    final skillColor = skillReady ? const Color(0xFF44FF44) : const Color(0xFF888888);
    final skillP = _buildText(skillName, skillSize, skillColor);
    canvas.drawParagraph(
      skillP,
      Offset(leftAligned ? x : x + infoWidth - skillP.width, y + textSize * 1.2),
    );

    // Cooldown arc + bar
    if (!skillReady) {
      final ratio = 1.0 - (fighter.skillCooldownTimer / fighter.skillCooldown).clamp(0.0, 1.0);

      // Arc indicator
      final arcRadius = 8.0 * (textSize / 14);
      final arcCenterX = leftAligned ? x + infoWidth * 0.45 : x + infoWidth - infoWidth * 0.45;
      final arcCenter = Offset(arcCenterX, y + textSize * 2.5);

      // Background circle
      final arcBgPaint = Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(arcCenter, arcRadius, arcBgPaint);

      // Progress arc (sweeps clockwise from top)
      final arcPaint = Paint()
        ..color = fighter.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (textSize / 14)
        ..strokeCap = StrokeCap.round;
      const startAngle = -1.5708; // -pi/2 (top)
      final sweepAngle = ratio * 6.2832; // ratio * 2*pi
      canvas.drawArc(
        Rect.fromCircle(center: arcCenter, radius: arcRadius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );

      // Cooldown text
      final cdText = '${fighter.skillCooldownTimer.toStringAsFixed(1)}s';
      final cdP = _buildText(cdText, textSize * 0.7, const Color(0xFF888888));
      canvas.drawParagraph(
        cdP,
        Offset(leftAligned ? x + infoWidth * 0.51 : x + infoWidth - infoWidth * 0.51 - cdP.width, y + textSize * 2),
      );
    } else {
      // Ready pulse — slightly larger text
      final readyP = _buildText('${l10n.ready}!', textSize * 0.8, const Color(0xFF44FF44));
      canvas.drawParagraph(
        readyP,
        Offset(leftAligned ? x : x + 200 - readyP.width, y + 28),
      );
    }
  }

  void _drawHPBar(Canvas canvas, double x, double y, double w, double h,
      double hp, double displayHp, double maxHp, Color color, {bool rightAligned = false, double textSize = 12}) {
    // Background
    final bgPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      bgPaint,
    );

    final actualRatio = (hp / maxHp).clamp(0.0, 1.0);
    final displayRatio = (displayHp / maxHp).clamp(0.0, 1.0);

    // Damage trail layer (shows where HP was, fades out)
    if (displayRatio > actualRatio) {
      final trailW = w * displayRatio;
      final trailX = rightAligned ? x + w - trailW : x;
      final trailPaint = Paint()..color = const Color(0xCCFF4444); // red trail
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(trailX, y, trailW, h), const Radius.circular(4)),
        trailPaint,
      );
    }

    // Current HP fill
    final fillW = w * actualRatio;
    final fillX = rightAligned ? x + w - fillW : x;
    final hpColor = actualRatio > 0.5
        ? color
        : actualRatio > 0.25
            ? const Color(0xFFFFAA00)
            : const Color(0xFFFF2222);
    final hpPaint = Paint()..color = hpColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(fillX, y, fillW, h), const Radius.circular(4)),
      hpPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = const Color(0xFFAAAAAA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4)),
      borderPaint,
    );

    // HP text
    final hpText = '${hp.ceil()}/${maxHp.ceil()}';
    final hpParagraph = _buildText(hpText, textSize * 0.5, const Color(0xFFFFFFFF));
    canvas.drawParagraph(hpParagraph, Offset(x + w / 2 - hpParagraph.width / 2, y + h / 2 - hpParagraph.height / 2));
  }

  void _drawComboCounter(Canvas canvas, Fighter fighter, int comboCount, double timer) {
    if (timer <= 0 || comboCount <= 0) return;

    // Position above the fighter
    final cx = fighter.position.x + Fighter.fighterWidth / 2;
    final cy = fighter.position.y - 30;

    // Fade out in last 0.5s
    final alpha = timer > 0.5 ? 1.0 : (timer / 0.5);

    // Scale pop effect — larger when fresh
    final scale = timer > 1.2 ? 1.0 + (timer - 1.2) * 2.0 : 1.0;
    final fontSize = (16.0 * scale).clamp(16.0, 22.0);

    final comboText = '${comboCount}HIT';
    final color = comboCount >= 3
        ? Color.fromRGBO(255, 200, 50, alpha)  // gold for 3+
        : Color.fromRGBO(255, 255, 255, alpha); // white otherwise

    final comboP = _buildText(comboText, fontSize, color);
    canvas.drawParagraph(comboP, Offset(cx - 25, cy));
  }

  void _renderOverlay(Canvas canvas, String title, String subtitle) {
    // Dim background
    final dimPaint = Paint()..color = const Color(0xAA000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, stageWidth, stageHeight), dimPaint);

    // Title
    final titleP = _buildText(title, 48, const Color(0xFFFFFFFF));
    canvas.drawParagraph(titleP, Offset(stageWidth / 2 - 150, stageHeight / 2 - 60));

    // Subtitle
    final subP = _buildText(subtitle, 18, const Color(0xFFAAAAAA));
    canvas.drawParagraph(subP, Offset(stageWidth / 2 - 120, stageHeight / 2 + 10));
  }

  Paragraph _buildText(String text, double fontSize, Color color) {
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: TextAlign.left,
      fontSize: fontSize,
    ))
      ..pushStyle(TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ))
      ..addText(text);
    final paragraph = builder.build();
    paragraph.layout(const ParagraphConstraints(width: 300));
    return paragraph;
  }
}
