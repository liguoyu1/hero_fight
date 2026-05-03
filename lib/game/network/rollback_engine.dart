import '../fighter_game.dart';
import '../components/fighter.dart';
import 'game_snapshot.dart';

/// GGPO-style rollback netcode engine for 2-player fighting games.
///
/// Core principles:
/// - Both clients run the same deterministic simulation at fixed 30fps.
/// - Local inputs execute immediately (zero delay feel).
/// - Remote inputs arrive with network delay; when they arrive late,
///   the engine rolls back to the last snapshot and re-simulates.
/// - [delayFrames] adds a small input buffer to reduce visible rollbacks.
///
/// Usage:
/// 1. Call [beforeFrame] at the start of each tick to save local input.
/// 2. Call [afterFrame] at the end of each tick to snapshot if needed.
/// 3. Call [receiveRemote] when remote input arrives from the network.
///    The engine handles rollback automatically.
class RollbackEngine {
  final FighterGame game;

  /// Number of frames to delay before applying remote input.
  /// Higher = fewer visible rollbacks, but more input lag.
  final int delayFrames;

  /// Save a snapshot every N frames for rollback recovery.
  final int snapshotInterval;

  /// Ring buffer size: how many frames of history to keep.
  final int bufferSize;

  // Ring buffers (index = frame % bufferSize)
  final List<FighterInput> _localInputs;
  final List<FighterInput?> _remoteInputs;
  final List<GameSnapshot?> _snapshots;

  /// Current simulation frame (monotonic).
  int _frame = -1;

  /// Latest remote frame number received.
  int _remoteFrame = -1;

  /// Number of rollbacks performed (for debugging/stats).
  int _rollbackCount = 0;

  /// Number of frames re-simulated during rollbacks (for debugging/stats).
  int _resimulatedFrames = 0;

  RollbackEngine({
    required this.game,
    this.delayFrames = 2,
    this.snapshotInterval = 4,
    this.bufferSize = 64,
  })  : _localInputs = List.filled(64, FighterInput.empty()),
        _remoteInputs = List.filled(64, null),
        _snapshots = List.filled(64, null) {
    // Pre-fill local input buffer with empty inputs
    for (int i = 0; i < bufferSize; i++) {
      _localInputs[i] = FighterInput.empty();
    }
  }

  /// Current frame number.
  int get frame => _frame;

  /// Latest confirmed frame (both local and remote known).
  int get confirmedFrame {
    var c = 0;
    for (int i = 0; i <= _frame; i++) {
      if (_remoteInputs[i % bufferSize] != null &&
          _remoteInputs[i % bufferSize]!.frame == i) {
        c = i;
      } else {
        break;
      }
    }
    return c;
  }

  int get rollbackCount => _rollbackCount;
  int get resimulatedFrames => _resimulatedFrames;
  int get currentFrame => _frame;

  /// Remote frame delay (how many frames behind remote is).
  int get remoteDelay => _frame - _remoteFrame;

  /// Latest local input as a map, for network sending.
  Map<String, dynamic> lastLocalInput() {
    final inp = _localInputs[_frame % bufferSize];
    return {
      'left': inp.left,
      'right': inp.right,
      'up': inp.up,
      'down': inp.down,
      'jump': inp.jump,
      'attack': inp.attack,
      'skill': inp.skill,
    };
  }

  // ---------------------------------------------------------------------------
  // Frame lifecycle
  // ---------------------------------------------------------------------------

  /// Call at the START of each fixed tick.
  /// Saves local input into the ring buffer.
  void beforeFrame(FighterInput localInput) {
    _frame++;

    // Copy local input into buffer with frame stamp
    final copy = localInput.copy();
    copy.frame = _frame;
    _localInputs[_frame % bufferSize] = copy;

    // Predict remote input: reuse previous frame's remote,
    // or empty if no remote has ever arrived.
    if (_remoteInputs[_frame % bufferSize] == null) {
      final prev = _remoteInputs[(_frame - 1) % bufferSize];
      if (prev != null) {
        _remoteInputs[_frame % bufferSize] = prev.copy();
        _remoteInputs[_frame % bufferSize]!.frame = _frame;
      }
    }
  }

  /// Call at the END of each fixed tick.
  /// Takes a snapshot if we are at a snapshot boundary.
  void afterFrame() {
    if (_frame % snapshotInterval == 0) {
      _snapshots[_frame % bufferSize] =
          GameSnapshot.fromGame(game, _frame);
    }
  }

  // ---------------------------------------------------------------------------
  // Network input
  // ---------------------------------------------------------------------------

  /// Receive remote input for a specific frame.
  /// If the frame is in the past, triggers a rollback.
  ///
  /// [frame]: the frame number this input was generated on.
  /// [input]: raw FighterInput (without frame stamp).
  void receiveRemote(int frame, FighterInput input) {
    // Validate frame
    if (frame < 0 || frame > _frame + delayFrames) return;

    // Stamp and store
    final copy = input.copy();
    copy.frame = frame;
    _remoteInputs[frame % bufferSize] = copy;

    if (frame > _remoteFrame) {
      _remoteFrame = frame;
    }

    // If this frame is behind our current simulation, rollback
    if (frame < _frame) {
      _rollback(frame);
    }
  }

  // ---------------------------------------------------------------------------
  // Input accessors (called by FighterGame during simulation)
  // ---------------------------------------------------------------------------

  /// Get the input to apply to the local player for the current frame.
  FighterInput get localInput {
    final idx = _frame % bufferSize;
    return _localInputs[idx];
  }

  /// Get the input to apply to the remote player for the current frame.
  /// Returns empty input if no remote data is available for this frame.
  FighterInput get remoteInput {
    final idx = _frame % bufferSize;
    return _remoteInputs[idx] ?? FighterInput.empty();
  }

  /// Check if we have confirmed remote input for the current frame.
  bool get hasRemoteInput =>
      _remoteInputs[_frame % bufferSize] != null;

  // ---------------------------------------------------------------------------
  // Rollback internals
  // ---------------------------------------------------------------------------

  /// Find the most recent snapshot at or before [targetFrame].
  GameSnapshot? _findSnapshot(int targetFrame) {
    // Scan backwards from the closest snapshot position
    final startSlot = targetFrame - (targetFrame % snapshotInterval);
    for (int slot = startSlot; slot >= 0; slot -= snapshotInterval) {
      final snap = _snapshots[slot % bufferSize];
      if (snap != null && snap.frameNumber <= targetFrame) {
        return snap;
      }
    }
    return null;
  }

  /// Roll back to [toFrame] and re-simulate forward.
  void _rollback(int toFrame) {
    if (toFrame >= _frame) return;

    final snapshot = _findSnapshot(toFrame);
    if (snapshot == null) return;

    _rollbackCount++;

    // 1. Restore game to snapshot state
    snapshot.restoreTo(game);

    // 2. Re-simulate from snapshot frame + 1 to current frame
    for (int f = snapshot.frameNumber + 1; f <= _frame; f++) {
      final local = _localInputs[f % bufferSize];
      final remote = _remoteInputs[f % bufferSize] ?? FighterInput.empty();

      // Apply inputs to fighters
      game.player1.input.copyFrom(local);
      game.player2.input.copyFrom(remote);

      // Run one tick of simulation
      game.resimulateTick();

      _resimulatedFrames++;
    }
  }
}
