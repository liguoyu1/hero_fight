import '../fighter_game.dart';
import '../components/projectile.dart';

/// Complete game state snapshot for rollback netcode.
///
/// Captures every mutable field that affects simulation determinism:
/// Fighter positions/velocities/HP/states/cooldowns, all projectiles,
/// PRNG state, round timer, and game phase.
///
/// Visual-only state (display HP, combo display timers) is excluded
/// since it doesn't affect gameplay simulation.
class GameSnapshot {
  final int frameNumber;

  final Map<String, dynamic> fighter1;
  final Map<String, dynamic> fighter2;
  final List<Map<String, dynamic>> projectiles;

  final int prngState;
  final double roundTimer;
  final String gameState;
  final String? winnerName;

  GameSnapshot({
    required this.frameNumber,
    required this.fighter1,
    required this.fighter2,
    required this.projectiles,
    required this.prngState,
    required this.roundTimer,
    required this.gameState,
    this.winnerName,
  });

  /// Capture current state from a running game.
  factory GameSnapshot.fromGame(FighterGame game, int frame) {
    return GameSnapshot(
      frameNumber: frame,
      fighter1: game.player1.toJson(),
      fighter2: game.player2.toJson(),
      projectiles: game.projectiles
          .where((p) => !p.expired)
          .map((p) => p.toJson())
          .toList(),
      prngState: game.gameRandom.state,
      roundTimer: game.roundTimer,
      gameState: game.gameState.name,
      winnerName: game.winnerName,
    );
  }

  /// Restore game state from this snapshot.
  ///
  /// Overwrites all mutable state on [game]. Does NOT add/remove
  /// components from the component tree — only updates existing ones.
  void restoreTo(FighterGame game) {
    // Restore fighters
    game.player1.fromJson(fighter1);
    game.player2.fromJson(fighter2);

    // Restore projectiles
    game.projectiles.clear();
    final fightersByIdx = {
      0: game.player1,
      1: game.player2,
    };
    for (final pData in projectiles) {
      final proj = Projectile.fromJson(pData, fightersByIdx);
      game.projectiles.add(proj);
    }

    // Restore PRNG state
    game.gameRandom.state = prngState;

    // Restore game phase
    game.roundTimer = roundTimer;
    game.gameState = GameState.values.firstWhere(
      (s) => s.name == gameState,
      orElse: () => GameState.fighting,
    );
    game.winnerName = winnerName;
  }

  /// Take a snapshot for every N frames. Returns null if [frame] is not
  /// a snapshot boundary.
  static GameSnapshot? maybeSnapshot(FighterGame game, int frame,
      {int interval = 8}) {
    if (frame % interval == 0) {
      return GameSnapshot.fromGame(game, frame);
    }
    return null;
  }

  /// Serialize for network transmission.
  Map<String, dynamic> toJson() => {
        'frame': frameNumber,
        'fighter1': fighter1,
        'fighter2': fighter2,
        'projectiles': projectiles,
        'prng': prngState,
        'roundTimer': roundTimer,
        'gameState': gameState,
        'winnerName': winnerName,
      };

  /// Deserialize from network.
  factory GameSnapshot.fromJson(Map<String, dynamic> json) {
    return GameSnapshot(
      frameNumber: json['frame'] as int,
      fighter1: Map<String, dynamic>.from(json['fighter1'] as Map),
      fighter2: Map<String, dynamic>.from(json['fighter2'] as Map),
      projectiles: (json['projectiles'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      prngState: json['prng'] as int,
      roundTimer: (json['roundTimer'] as num).toDouble(),
      gameState: json['gameState'] as String,
      winnerName: json['winnerName'] as String?,
    );
  }
}
