/// Deterministic pseudo-random number generator for rollback netcode.
///
/// Uses xorshift32 algorithm — fast, simple, and produces
/// identical sequences given the same seed across all platforms.
class GameRandom {
  static const int _maxInt = 0x7FFFFFFF;

  int _state;

  /// Create a deterministic PRNG with the given [seed].
  /// A seed of 0 is automatically replaced with 1 (xorshift requires non-zero).
  GameRandom([int seed = 12345])
      : _state = seed == 0 ? 1 : seed;

  /// Returns the next random integer in the range [0, [max]).
  int nextInt(int max) {
    if (max <= 0) return 0;
    final r = _next();
    return (r & _maxInt) % max;
  }

  /// Returns true approximately half the time.
  bool nextBool() {
    return (_next() & 1) == 0;
  }

  /// Returns the next random double in the range [0.0, 1.0).
  double nextDouble() {
    return (_next() & _maxInt) / (_maxInt + 1.0);
  }

  /// Returns the next random double in the range [-1.0, 1.0).
  double nextSignedDouble() {
    return nextDouble() * 2.0 - 1.0;
  }

  /// Core xorshift32 step.
  int _next() {
    _state ^= _state << 13;
    _state ^= _state >> 17;
    _state ^= _state << 5;
    return _state;
  }

  /// Create a copy with the same state (for snapshot/restore).
  GameRandom clone() => GameRandom(0).._state = _state;

  /// Current state for serialization (snapshot purposes).
  int get state => _state;

  /// Restore state from serialized value.
  set state(int value) {
    _state = value == 0 ? 1 : value;
  }
}
