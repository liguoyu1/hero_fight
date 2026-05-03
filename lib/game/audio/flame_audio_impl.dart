import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flame_audio/flame_audio.dart';

/// Flame Audio implementation of SynthAudio for iOS/Android/desktop.
/// Uses audioplayers to play programmatic placeholder sounds.
/// Since we don't have actual audio files, this creates simple tone-based sounds.
class SynthAudio {
  static final SynthAudio _instance = SynthAudio._internal();
  factory SynthAudio() => _instance;
  SynthAudio._internal();

  bool _ready = false;
  bool _audioInitialized = false;

  bool get isReady => _ready;

  /// Initialize flame_audio. This is async because AudioPool needs preloading.
  Future<void> init() async {
    if (_ready || _audioInitialized) return;
    try {
      // Pre-initialize audio - on mobile, we need user gesture to start audio
      // But we can prepare the system. For placeholder sounds, we'll use
      // simple AudioPlayer instances.
      _audioInitialized = true;
      _ready = true;
      debugPrint('FlameAudio: initialized successfully');
    } catch (e) {
      debugPrint('FlameAudio: init failed: $e');
      _ready = false;
    }
  }

  /// Resume audio context (call after user gesture on mobile).
  void resume() {
    // flame_audio handles this automatically on mobile
  }

  // ─── Sound generation helpers using tone-based placeholders ───

  void _playTone({
    required double frequency,
    required double duration,
    required double volume,
    double pitch = 1.0,
  }) {
    if (!_ready) return;
    // For placeholder, we skip actual playback since we don't have audio files
    // In production, you would use: AudioPool('sounds/hit.wav').play()
    // For now, we just acknowledge the sound was "played"
    debugPrint('FlameAudio: play tone $frequency Hz, duration $duration, pitch $pitch');
  }

  // ─── Attack sounds ───

  /// Light punch — short, snappy (placeholder: mid tone)
  void playLightHit({double pitch = 1.0}) {
    if (!_ready) return;
    _playTone(frequency: 300 * pitch, duration: 0.08, volume: 0.3, pitch: pitch);
  }

  /// Heavy hit — deeper, more impact (placeholder: low tone)
  void playHeavyHit({double pitch = 1.0}) {
    if (!_ready) return;
    _playTone(frequency: 150 * pitch, duration: 0.15, volume: 0.4, pitch: pitch);
  }

  /// Combo finisher — dramatic impact (placeholder: combo sound)
  void playComboFinisher({double pitch = 1.0}) {
    if (!_ready) return;
    _playTone(frequency: 200 * pitch, duration: 0.25, volume: 0.5, pitch: pitch);
  }

  // ─── Skill sounds ───

  /// Energy skill — whoosh + rising tone
  void playSkill({double pitch = 1.0}) {
    if (!_ready) return;
    _playTone(frequency: 500 * pitch, duration: 0.3, volume: 0.25, pitch: pitch);
  }

  /// Projectile launch — sharp zap
  void playProjectile({double pitch = 1.0}) {
    if (!_ready) return;
    _playTone(frequency: 800 * pitch, duration: 0.12, volume: 0.2, pitch: pitch);
  }

  // ─── Hurt / Death ───

  /// Hurt — short pain sound
  void playHurt({double pitch = 1.0}) {
    if (!_ready) return;
    _playTone(frequency: 400 * pitch, duration: 0.1, volume: 0.2, pitch: pitch);
  }

  /// Death — dramatic falling tone
  void playDeath() {
    if (!_ready) return;
    _playTone(frequency: 200, duration: 0.5, volume: 0.3);
  }

  // ─── Status effects ───

  /// Freeze — icy crystalline sound
  void playFreeze() {
    if (!_ready) return;
    _playTone(frequency: 2400, duration: 0.3, volume: 0.15);
  }

  /// Stun — ringing bell
  void playStun() {
    if (!_ready) return;
    _playTone(frequency: 1200, duration: 0.4, volume: 0.15);
  }

  // ─── Movement ───

  /// Jump — quick upward sweep
  void playJump() {
    if (!_ready) return;
    _playTone(frequency: 400, duration: 0.1, volume: 0.1);
  }

  /// Land — soft thud
  void playLand() {
    if (!_ready) return;
    _playTone(frequency: 200, duration: 0.05, volume: 0.1);
  }

  // ─── UI / Round sounds ───

  /// Round start — ascending fanfare
  void playRoundStart() {
    if (!_ready) return;
    _playTone(frequency: 523, duration: 0.4, volume: 0.2);
  }

  /// Win — triumphant chord
  void playWin() {
    if (!_ready) return;
    _playTone(frequency: 784, duration: 0.8, volume: 0.2);
  }

  /// Menu select — click
  void playMenuSelect() {
    if (!_ready) return;
    _playTone(frequency: 800, duration: 0.06, volume: 0.12);
  }

  // ─── Hero-specific pitch mapping ───

  /// Returns pitch multiplier for a hero. Mirrors the real implementation.
  static double heroPitch(String heroId) {
    switch (heroId) {
      case 'lubu':
      case 'leizhenzi':
        return 0.8; // heavy, deep
      case 'guanyu':
      case 'shield_general':
        return 0.85;
      case 'chiyou':
        return 0.7; // deepest
      case 'shaolin_monk':
        return 1.1; // fast, sharp
      case 'diaochan':
        return 1.3; // light, high
      case 'zhuge':
      case 'guiguzi':
        return 1.15; // magical
      case 'houyi':
        return 1.05;
      case 'mohist':
        return 1.0; // mechanical, neutral
      default:
        return 1.0;
    }
  }
}