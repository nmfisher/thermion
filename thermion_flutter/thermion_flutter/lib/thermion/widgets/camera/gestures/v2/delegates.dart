import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

abstract class RotateCameraDelegate {
  Future<void> rotateCamera(Offset delta, Vector2? velocity);
}

abstract class PanCameraDelegate {
  Future<void> panCamera(Offset delta, Vector2? velocity);
}

abstract class ZoomCameraDelegate {
  Future<void> zoomCamera(double scrollDelta, Vector2? velocity);
}

abstract class VelocityDelegate {
  Vector2? get velocity;

  void updateVelocity(Offset delta);

  void startDeceleration();

  void stopDeceleration();

  void dispose() {
    stopDeceleration();
  }
}
