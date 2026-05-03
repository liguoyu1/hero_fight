/// Stub implementation of [SynthAudio] for non-web platforms.
///
/// All methods are no-ops. This file is selected via conditional import
/// in `sound_manager.dart` when `dart.library.js_interop` is unavailable.
class SynthAudio {
  static final SynthAudio _instance = SynthAudio._internal();
  factory SynthAudio() => _instance;
  SynthAudio._internal();

  bool get isReady => false;

  void init() {}
  void resume() {}

  void playLightHit({double pitch = 1.0}) {}
  void playHeavyHit({double pitch = 1.0}) {}
  void playComboFinisher({double pitch = 1.0}) {}
  void playSkill({double pitch = 1.0}) {}
  void playProjectile({double pitch = 1.0}) {}
  void playHurt({double pitch = 1.0}) {}
  void playDeath() {}
  void playFreeze() {}
  void playStun() {}
  void playJump() {}
  void playLand() {}
  void playRoundStart() {}
  void playWin() {}
  void playMenuSelect() {}

  /// Returns pitch multiplier for a hero. Mirrors the real implementation.
  static double heroPitch(String heroId) {
    switch (heroId) {
      case 'lubu':
        return 0.8;
      case 'zhuge':
        return 1.1;
      case 'diaochan':
        return 1.3;
      case 'guanyu':
        return 0.7;
      case 'zhaoyun':
        return 1.0;
      case 'sunshangxiang':
        return 1.2;
      case 'caocao':
        return 0.9;
      case 'huangzhong':
        return 0.75;
      case 'machao':
        return 0.85;
      case 'zhouyu':
        return 1.05;
      case 'simayi':
        return 0.95;
      case 'dianwei':
        return 0.7;
      default:
        return 1.0;
    }
  }
}
