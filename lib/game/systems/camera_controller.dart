import 'package:flame/components.dart';

import '../components/effects.dart' show ScreenShake;

/// Manages camera position, viewfinder, and screen shake effects.
class CameraController {
  final ScreenShake screenShake = ScreenShake();

  /// Update camera to follow the midpoint of two fighters with screen shake.
  void update(CameraComponent camera, double stageWidth, double stageHeight) {
    camera.viewfinder.position = Vector2(stageWidth / 2, stageHeight / 2) + screenShake.currentOffset;
  }
}
