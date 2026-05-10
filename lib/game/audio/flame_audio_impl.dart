import 'package:flutter/foundation.dart';
import 'package:flame_audio/flame_audio.dart';

/// Flame Audio implementation for iOS/Android/desktop.
/// Uses flame_audio to play WAV files from assets/sounds/.
class SynthAudio {
  static final SynthAudio _instance = SynthAudio._internal();
  factory SynthAudio() => _instance;
  SynthAudio._internal();

  bool _ready = false;

  // Audio pools for frequently-played sounds
  AudioPool? _hitPool;
  AudioPool? _heavyHitPool;
  AudioPool? _skillPool;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    try {
      FlameAudio.audioCache.loadAll([
        'sounds/attack.wav',
        'sounds/death.wav',
        'sounds/skill.wav',
        'sounds/start.wav',
        'sounds/win.wav',
        'sounds/hit.wav',
        'sounds/jump.wav',
      ]);
      _hitPool = await FlameAudio.createPool('sounds/hit.wav', maxPlayers: 4);
      _heavyHitPool = await FlameAudio.createPool('sounds/attack.wav', maxPlayers: 3);
      _skillPool = await FlameAudio.createPool('sounds/skill.wav', maxPlayers: 3);
      _ready = true;
      debugPrint('FlameAudio: initialized with WAV files');
    } catch (e) {
      debugPrint('FlameAudio: init failed: $e');
      _ready = false;
    }
  }

  void resume() {
    // flame_audio handles audio session automatically
  }

  void _playSound(String path, {double volume = 0.5}) {
    if (!_ready) return;
    FlameAudio.play(path, volume: volume);
  }

  void _playPool(AudioPool? pool, {double volume = 0.5}) {
    if (!_ready || pool == null) return;
    pool.start(volume: volume);
  }

  // ─── Attack sounds ───
  void playLightHit({double pitch = 1.0}) => _playPool(_hitPool);
  void playHeavyHit({double pitch = 1.0}) => _playPool(_heavyHitPool);
  void playComboFinisher({double pitch = 1.0}) => _playPool(_heavyHitPool);

  // ─── Skill sounds ───
  void playSkill({double pitch = 1.0}) => _playPool(_skillPool);
  void playProjectile({double pitch = 1.0}) => _playPool(_skillPool);

  // ─── Hurt / Death ───
  void playHurt({double pitch = 1.0}) => _playSound('sounds/hit.wav');
  void playDeath() => _playSound('sounds/death.wav');

  // ─── Status effects ───
  void playFreeze() => _playSound('sounds/skill.wav', volume: 0.3);
  void playStun() => _playSound('sounds/hit.wav', volume: 0.2);

  // ─── Movement ───
  void playJump() => _playSound('sounds/jump.wav', volume: 0.3);
  void playLand() => _playSound('sounds/jump.wav', volume: 0.15);

  // ─── UI / Round ───
  void playRoundStart() => _playSound('sounds/start.wav');
  void playWin() => _playSound('sounds/win.wav');
  void playMenuSelect() => _playSound('sounds/hit.wav', volume: 0.15);

  // ─── Hero-specific pitch mapping ───
  static double heroPitch(String heroId) {
    switch (heroId) {
      case 'lubu': case 'leizhenzi': return 0.8;
      case 'guanyu': case 'shield_general': return 0.85;
      case 'chiyou': return 0.7;
      case 'shaolin_monk': return 1.1;
      case 'diaochan': return 1.3;
      case 'zhuge': case 'guiguzi': return 1.15;
      case 'houyi': return 1.05;
      case 'mohist': return 1.0;
      case 'jingke': return 1.2;
      default: return 1.0;
    }
  }
}
