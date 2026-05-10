import 'package:flutter/services.dart';

import '../components/fighter.dart' show FighterInput;
import '../components/touch_controls.dart' show TouchControls;

/// Handles keyboard/touch input processing and maps to [FighterInput].
/// Extracted from FighterGame to keep the game class focused on game loop.
class InputSystem {
  final Set<LogicalKeyboardKey> keysPressed = {};

  /// Collect P1's input from keyboard + optional touch controls.
  /// [localPlayerIndex]: 0 = P1 (WASD+JK), 1 = P2 (Arrows+Numpad)
  FighterInput collectInput({
    required int localPlayerIndex,
    TouchControls? touchControls,
  }) {
    final input = FighterInput.empty();

    if (localPlayerIndex == 0) {
      // P1: WASD + J/K
      input.left = keysPressed.contains(LogicalKeyboardKey.keyA);
      input.right = keysPressed.contains(LogicalKeyboardKey.keyD);
      input.up = keysPressed.contains(LogicalKeyboardKey.keyW);
      input.down = keysPressed.contains(LogicalKeyboardKey.keyS);
      input.attack = keysPressed.contains(LogicalKeyboardKey.keyJ);
      input.skill = keysPressed.contains(LogicalKeyboardKey.keyK);
    } else {
      // P2: Arrow keys + Numpad 1/2
      input.left = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
      input.right = keysPressed.contains(LogicalKeyboardKey.arrowRight);
      input.up = keysPressed.contains(LogicalKeyboardKey.arrowUp);
      input.down = keysPressed.contains(LogicalKeyboardKey.arrowDown);
      input.attack = keysPressed.contains(LogicalKeyboardKey.numpad1);
      input.skill = keysPressed.contains(LogicalKeyboardKey.numpad2);
    }

    // Touch overrides for P1 only
    if (localPlayerIndex == 0 && touchControls != null) {
      final ti = touchControls.input;
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

  /// Build P1 network input map from current key state
  Map<String, bool> buildP1NetworkInput() {
    return {
      'left': keysPressed.contains(LogicalKeyboardKey.keyA),
      'right': keysPressed.contains(LogicalKeyboardKey.keyD),
      'up': keysPressed.contains(LogicalKeyboardKey.keyW),
      'down': keysPressed.contains(LogicalKeyboardKey.keyS),
      'jump': false,
      'attack': keysPressed.contains(LogicalKeyboardKey.keyJ),
      'skill': keysPressed.contains(LogicalKeyboardKey.keyK),
    };
  }

  /// Build P2 network input map from current key state
  Map<String, bool> buildP2NetworkInput() {
    return {
      'left': keysPressed.contains(LogicalKeyboardKey.arrowLeft),
      'right': keysPressed.contains(LogicalKeyboardKey.arrowRight),
      'up': keysPressed.contains(LogicalKeyboardKey.arrowUp),
      'down': keysPressed.contains(LogicalKeyboardKey.arrowDown),
      'jump': false,
      'attack': keysPressed.contains(LogicalKeyboardKey.numpad1),
      'skill': keysPressed.contains(LogicalKeyboardKey.numpad2),
    };
  }
}
