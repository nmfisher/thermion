import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

abstract class CameraDelegate {
  Future<void> rotate(Offset delta, Vector2? velocity);
  Future<void> pan(Offset delta, Vector2? velocity);
  Future<void> zoom(double scrollDelta, Vector2? velocity);
  Future<void> onKeypress(PhysicalKeyboardKey key);
  Future<void> onKeyRelease(PhysicalKeyboardKey key);
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
