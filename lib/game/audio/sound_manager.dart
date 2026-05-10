import 'package:flutter/foundation.dart';
import 'flame_audio_impl.dart'
    if (dart.library.js_interop) 'synth_audio.dart';

/// Sound effect manager for Hero Fighter.
/// Delegates to SynthAudio (Web Audio API) on web,
/// flame_audio on iOS/Android/desktop,
/// silently no-ops on unsupported platforms.
class SoundManager {
  static final SoundManager _instance = SoundManager._();
  factory SoundManager() => _instance;
  SoundManager._();

  bool _initialized = false;
  bool _enabled = true;
  SynthAudio? _synth;

  /// Enable or disable all sound effects
  void setEnabled(bool enabled) => _enabled = enabled;
  bool get isEnabled => _enabled;

  /// Initialize audio. On web, sets up SynthAudio. On mobile/desktop, sets up flame_audio.
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      try {
        _synth = SynthAudio();
        _synth!.init();
        _initialized = _synth!.isReady;
      } catch (e) {
        debugPrint('SoundManager: init failed: $e');
        _initialized = false;
      }
    } else {
      // Non-web platforms (iOS, Android, desktop) - flame_audio
      try {
        _synth = SynthAudio();
        _synth!.init();
        _initialized = _synth!.isReady;
      } catch (e) {
        debugPrint('SoundManager: flame_audio init failed: $e');
        _initialized = false;
      }
    }
  }

  bool get isReady => _initialized;

  /// Resume audio context (call after user gesture on web).
  void resume() => _synth?.resume();

  // ─── Attack sounds (hero-aware) ───

  void _play(void Function() fn) {
    if (_enabled) fn();
  }

  /// Light hit with hero pitch.
  void playLightHit({String heroId = ''}) {
    _play(() => _synth?.playLightHit(pitch: SynthAudio.heroPitch(heroId)));
  }

  /// Heavy hit with hero pitch.
  void playHeavyHit({String heroId = ''}) {
    _play(() => _synth?.playHeavyHit(pitch: SynthAudio.heroPitch(heroId)));
  }

  /// Combo finisher with hero pitch.
  void playComboFinisher({String heroId = ''}) {
    _play(() => _synth?.playComboFinisher(pitch: SynthAudio.heroPitch(heroId)));
  }

  // ─── Skill sounds ───

  void playSkill({String heroId = ''}) {
    _play(() => _synth?.playSkill(pitch: SynthAudio.heroPitch(heroId)));
  }

  void playProjectile({String heroId = ''}) {
    _play(() => _synth?.playProjectile(pitch: SynthAudio.heroPitch(heroId)));
  }

  // ─── Hurt / Death ───

  void playHurt({String heroId = ''}) {
    _play(() => _synth?.playHurt(pitch: SynthAudio.heroPitch(heroId)));
  }

  void playDeath() => _play(() => _synth?.playDeath());

  // ─── Status effects ───

  void playFreeze() => _play(() => _synth?.playFreeze());
  void playStun() => _play(() => _synth?.playStun());

  // ─── Movement ───

  void playJump() => _play(() => _synth?.playJump());
  void playLand() => _play(() => _synth?.playLand());

  // ─── UI / Round ───

  void playRoundStart() => _play(() => _synth?.playRoundStart());
  void playWin() => _play(() => _synth?.playWin());
  void playMenuSelect() => _play(() => _synth?.playMenuSelect());

  // ─── Legacy compatibility ───

  void playAttack() => _play(() => _synth?.playLightHit());
}
