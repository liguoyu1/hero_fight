import 'dart:math';
import 'package:flutter/foundation.dart';

// Web Audio API interop — only available on web platform
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Programmatic sound effect synthesizer using Web Audio API.
/// Generates all game sounds from code — no audio files needed.
class SynthAudio {
  static final SynthAudio _instance = SynthAudio._();
  factory SynthAudio() => _instance;
  SynthAudio._();

  web.AudioContext? _ctx;
  final _rand = Random();
  bool _ready = false;

  bool get isReady => _ready;

  /// Initialize the audio context. Call once at game start.
  void init() {
    if (_ready) return;
    try {
      _ctx = web.AudioContext();
      _ready = true;
    } catch (e) {
      debugPrint('SynthAudio: Web Audio not available: $e');
      _ready = false;
    }
  }

  /// Resume audio context (required after user gesture on web).
  void resume() {
    _ctx?.resume();
  }

  // ─── Core oscillator helpers ───

  web.OscillatorNode _osc(String type, double freq) {
    final o = _ctx!.createOscillator();
    o.type = type;
    o.frequency.value = freq;
    return o;
  }

  web.GainNode _gain(double vol) {
    final g = _ctx!.createGain();
    g.gain.value = vol;
    return g;
  }

  web.BiquadFilterNode _filter(String type, double freq, [double q = 1.0]) {
    final f = _ctx!.createBiquadFilter();
    f.type = type;
    f.frequency.value = freq;
    f.Q.value = q;
    return f;
  }

  double get _now => _ctx!.currentTime;

  /// White noise buffer
  web.AudioBufferSourceNode _noise(double duration) {
    final sr = _ctx!.sampleRate.toInt();
    final len = (sr * duration).toInt();
    final buf = _ctx!.createBuffer(1, len, sr.toDouble());
    final data = buf.getChannelData(0);
    final dartData = data.toDart;
    for (int i = 0; i < len; i++) {
      dartData[i] = _rand.nextDouble() * 2 - 1;
    }
    final src = _ctx!.createBufferSource();
    src.buffer = buf;
    return src;
  }

  // ─── Attack sounds ───

  /// Light punch — short, snappy
  void playLightHit({double pitch = 1.0}) {
    if (!_ready) return;
    final t = _now;
    // Impact noise burst
    final n = _noise(0.08);
    final ng = _gain(0.3);
    final nf = _filter('highpass', 800 * pitch, 2);
    n.connect(nf);
    nf.connect(ng);
    ng.connect(_ctx!.destination);
    ng.gain.setValueAtTime(0.3, t);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.08);
    n.start(t);
    n.stop(t + 0.08);

    // Thud tone
    final o = _osc('sine', 150 * pitch);
    final og = _gain(0.2);
    o.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.2, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
    o.frequency.exponentialRampToValueAtTime(60 * pitch, t + 0.06);
    o.start(t);
    o.stop(t + 0.07);
  }

  /// Heavy hit — deeper, more impact
  void playHeavyHit({double pitch = 1.0}) {
    if (!_ready) return;
    final t = _now;
    // Noise burst
    final n = _noise(0.15);
    final ng = _gain(0.4);
    final nf = _filter('bandpass', 600 * pitch, 1.5);
    n.connect(nf);
    nf.connect(ng);
    ng.connect(_ctx!.destination);
    ng.gain.setValueAtTime(0.4, t);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.15);
    n.start(t);
    n.stop(t + 0.15);

    // Deep thud
    final o = _osc('sine', 100 * pitch);
    final og = _gain(0.35);
    o.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.35, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
    o.frequency.exponentialRampToValueAtTime(40 * pitch, t + 0.12);
    o.start(t);
    o.stop(t + 0.13);

    // Sub bass
    final sub = _osc('sine', 60 * pitch);
    final sg = _gain(0.25);
    sub.connect(sg);
    sg.connect(_ctx!.destination);
    sg.gain.setValueAtTime(0.25, t);
    sg.gain.exponentialRampToValueAtTime(0.001, t + 0.18);
    sub.start(t);
    sub.stop(t + 0.19);
  }

  /// Combo finisher — dramatic impact
  void playComboFinisher({double pitch = 1.0}) {
    if (!_ready) return;
    final t = _now;
    // Big noise burst
    final n = _noise(0.2);
    final ng = _gain(0.5);
    final nf = _filter('bandpass', 500 * pitch, 1);
    n.connect(nf);
    nf.connect(ng);
    ng.connect(_ctx!.destination);
    ng.gain.setValueAtTime(0.5, t);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.2);
    n.start(t);
    n.stop(t + 0.2);

    // Impact tone sweep
    final o = _osc('sawtooth', 200 * pitch);
    final og = _gain(0.3);
    final of2 = _filter('lowpass', 1200 * pitch);
    o.connect(of2);
    of2.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.3, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.25);
    o.frequency.exponentialRampToValueAtTime(50 * pitch, t + 0.2);
    o.start(t);
    o.stop(t + 0.26);

    // Sub boom
    final sub = _osc('sine', 50 * pitch);
    final sg = _gain(0.4);
    sub.connect(sg);
    sg.connect(_ctx!.destination);
    sg.gain.setValueAtTime(0.4, t);
    sg.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
    sub.start(t);
    sub.stop(t + 0.31);
  }

  // ─── Skill sounds ───

  /// Energy skill — whoosh + rising tone
  void playSkill({double pitch = 1.0}) {
    if (!_ready) return;
    final t = _now;
    // Whoosh noise
    final n = _noise(0.3);
    final ng = _gain(0.25);
    final nf = _filter('bandpass', 2000 * pitch, 3);
    n.connect(nf);
    nf.connect(ng);
    ng.connect(_ctx!.destination);
    ng.gain.setValueAtTime(0.05, t);
    ng.gain.linearRampToValueAtTime(0.25, t + 0.1);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
    nf.frequency.exponentialRampToValueAtTime(4000 * pitch, t + 0.15);
    nf.frequency.exponentialRampToValueAtTime(800 * pitch, t + 0.3);
    n.start(t);
    n.stop(t + 0.3);

    // Rising tone
    final o = _osc('sine', 300 * pitch);
    final og = _gain(0.2);
    o.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.2, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.25);
    o.frequency.exponentialRampToValueAtTime(800 * pitch, t + 0.2);
    o.start(t);
    o.stop(t + 0.26);
  }

  /// Projectile launch — sharp zap
  void playProjectile({double pitch = 1.0}) {
    if (!_ready) return;
    final t = _now;
    final o = _osc('sawtooth', 600 * pitch);
    final og = _gain(0.15);
    final of2 = _filter('lowpass', 3000 * pitch);
    o.connect(of2);
    of2.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.15, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
    o.frequency.exponentialRampToValueAtTime(200 * pitch, t + 0.1);
    o.start(t);
    o.stop(t + 0.13);
  }

  // ─── Hurt / Death ───

  /// Hurt — short pain sound
  void playHurt({double pitch = 1.0}) {
    if (!_ready) return;
    final t = _now;
    // Impact
    final n = _noise(0.06);
    final ng = _gain(0.2);
    final nf = _filter('highpass', 1200 * pitch);
    n.connect(nf);
    nf.connect(ng);
    ng.connect(_ctx!.destination);
    ng.gain.setValueAtTime(0.2, t);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
    n.start(t);
    n.stop(t + 0.06);

    // Vocal-like tone
    final o = _osc('triangle', 400 * pitch);
    final og = _gain(0.15);
    o.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.15, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.1);
    o.frequency.exponentialRampToValueAtTime(250 * pitch, t + 0.1);
    o.start(t);
    o.stop(t + 0.11);
  }

  /// Death — dramatic falling tone
  void playDeath() {
    if (!_ready) return;
    final t = _now;
    // Long noise
    final n = _noise(0.5);
    final ng = _gain(0.3);
    final nf = _filter('lowpass', 2000);
    n.connect(nf);
    nf.connect(ng);
    ng.connect(_ctx!.destination);
    ng.gain.setValueAtTime(0.3, t);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.5);
    nf.frequency.exponentialRampToValueAtTime(200, t + 0.5);
    n.start(t);
    n.stop(t + 0.5);

    // Falling tone
    final o = _osc('sine', 300);
    final og = _gain(0.25);
    o.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.25, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.4);
    o.frequency.exponentialRampToValueAtTime(40, t + 0.4);
    o.start(t);
    o.stop(t + 0.41);
  }

  // ─── Status effects ───

  /// Freeze — icy crystalline sound
  void playFreeze() {
    if (!_ready) return;
    final t = _now;
    // High shimmer
    final o1 = _osc('sine', 2400);
    final o1g = _gain(0.12);
    o1.connect(o1g);
    o1g.connect(_ctx!.destination);
    o1g.gain.setValueAtTime(0.12, t);
    o1g.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
    o1.frequency.setValueAtTime(2400, t);
    o1.frequency.exponentialRampToValueAtTime(3200, t + 0.15);
    o1.frequency.exponentialRampToValueAtTime(1800, t + 0.3);
    o1.start(t);
    o1.stop(t + 0.3);

    // Crackle noise
    final n = _noise(0.15);
    final ng = _gain(0.15);
    final nf = _filter('highpass', 4000, 5);
    n.connect(nf);
    nf.connect(ng);
    ng.connect(_ctx!.destination);
    ng.gain.setValueAtTime(0.15, t + 0.05);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.2);
    n.start(t + 0.05);
    n.stop(t + 0.2);
  }

  /// Stun — ringing bell
  void playStun() {
    if (!_ready) return;
    final t = _now;
    final o = _osc('sine', 1200);
    final og = _gain(0.15);
    o.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.15, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.4);
    o.start(t);
    o.stop(t + 0.41);

    // Second harmonic
    final o2 = _osc('sine', 1800);
    final o2g = _gain(0.08);
    o2.connect(o2g);
    o2g.connect(_ctx!.destination);
    o2g.gain.setValueAtTime(0.08, t);
    o2g.gain.exponentialRampToValueAtTime(0.001, t + 0.35);
    o2.start(t);
    o2.stop(t + 0.36);
  }

  // ─── Movement ───

  /// Jump — quick upward sweep
  void playJump() {
    if (!_ready) return;
    final t = _now;
    final o = _osc('sine', 200);
    final og = _gain(0.1);
    o.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.1, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.1);
    o.frequency.exponentialRampToValueAtTime(600, t + 0.08);
    o.start(t);
    o.stop(t + 0.11);
  }

  /// Land — soft thud
  void playLand() {
    if (!_ready) return;
    final t = _now;
    final n = _noise(0.05);
    final ng = _gain(0.1);
    final nf = _filter('lowpass', 500);
    n.connect(nf);
    nf.connect(ng);
    ng.connect(_ctx!.destination);
    ng.gain.setValueAtTime(0.1, t);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.05);
    n.start(t);
    n.stop(t + 0.05);
  }

  // ─── UI / Round sounds ───

  /// Round start — ascending fanfare
  void playRoundStart() {
    if (!_ready) return;
    final t = _now;
    const notes = [523.25, 659.25, 783.99]; // C5, E5, G5
    for (int i = 0; i < notes.length; i++) {
      final delay = i * 0.12;
      final o = _osc('triangle', notes[i]);
      final og = _gain(0.2);
      o.connect(og);
      og.connect(_ctx!.destination);
      og.gain.setValueAtTime(0.001, t + delay);
      og.gain.linearRampToValueAtTime(0.2, t + delay + 0.02);
      og.gain.exponentialRampToValueAtTime(0.001, t + delay + 0.3);
      o.start(t + delay);
      o.stop(t + delay + 0.31);
    }
  }

  /// Win — triumphant chord
  void playWin() {
    if (!_ready) return;
    final t = _now;
    const chord = [523.25, 659.25, 783.99, 1046.5]; // C5, E5, G5, C6
    for (final freq in chord) {
      final o = _osc('triangle', freq);
      final og = _gain(0.15);
      o.connect(og);
      og.connect(_ctx!.destination);
      og.gain.setValueAtTime(0.001, t);
      og.gain.linearRampToValueAtTime(0.15, t + 0.05);
      og.gain.exponentialRampToValueAtTime(0.001, t + 0.8);
      o.start(t);
      o.stop(t + 0.81);
    }
  }

  /// Menu select — click
  void playMenuSelect() {
    if (!_ready) return;
    final t = _now;
    final o = _osc('sine', 800);
    final og = _gain(0.12);
    o.connect(og);
    og.connect(_ctx!.destination);
    og.gain.setValueAtTime(0.12, t);
    og.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
    o.start(t);
    o.stop(t + 0.07);
  }

  // ─── Hero-specific pitch mapping ───

  /// Get pitch multiplier for hero type.
  /// Heavy heroes = lower pitch, light heroes = higher pitch.
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
