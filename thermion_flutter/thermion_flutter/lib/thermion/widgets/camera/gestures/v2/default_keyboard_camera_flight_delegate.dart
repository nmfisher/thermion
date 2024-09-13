import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class DefaultKeyboardCameraFlightDelegate
     {
  final ThermionViewer viewer;

  static const double _panSensitivity = 0.005;
  static const double _keyMoveSensitivity = 0.1;

  final Map<PhysicalKeyboardKey, bool> _pressedKeys = {};
  Timer? _moveTimer;

  DefaultKeyboardCameraFlightDelegate(this.viewer) {
    _startMoveLoop();
  }

  @override
  Future<void> panCamera(Offset delta, Vector2? velocity) async {
    double deltaX = delta.dx;
    double deltaY = delta.dy;
    deltaX *= _panSensitivity * viewer.pixelRatio;
    deltaY *= _panSensitivity * viewer.pixelRatio;

    await _moveCamera(deltaX, deltaY, 0);
  }

  @override
  Future<void> onKeypress(PhysicalKeyboardKey key) async {
    _pressedKeys[key] = true;
  }

  // New method to handle key release
  Future<void> onKeyRelease(PhysicalKeyboardKey key) async {
    _pressedKeys.remove(key);
  }

  void _startMoveLoop() {
    _moveTimer = Timer.periodic(
        Duration(milliseconds: 16), (_) => _processKeyboardInput());
  }

  Future<void> _processKeyboardInput() async {
    double dx = 0, dy = 0, dz = 0;

    if (_pressedKeys[PhysicalKeyboardKey.keyW] == true)
      dz += _keyMoveSensitivity;
    if (_pressedKeys[PhysicalKeyboardKey.keyS] == true)
      dz -= _keyMoveSensitivity;
    if (_pressedKeys[PhysicalKeyboardKey.keyA] == true)
      dx -= _keyMoveSensitivity;
    if (_pressedKeys[PhysicalKeyboardKey.keyD] == true)
      dx += _keyMoveSensitivity;

    if (dx != 0 || dy != 0 || dz != 0) {
      await _moveCamera(dx, dy, dz);
    }
    // Removed _pressedKeys.clear(); from here
  }

  Future<void> _moveCamera(double dx, double dy, double dz) async {
    Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
    Vector3 currentPosition = currentModelMatrix.getTranslation();
    Quaternion currentRotation =
        Quaternion.fromRotation(currentModelMatrix.getRotation());

    Vector3 forward = Vector3(0, 0, -1)..applyQuaternion(currentRotation);
    Vector3 right = Vector3(1, 0, 0)..applyQuaternion(currentRotation);
    Vector3 up = Vector3(0, 1, 0)..applyQuaternion(currentRotation);

    Vector3 moveOffset = right * dx + up * dy + forward * dz;
    Vector3 newPosition = currentPosition + moveOffset;

    Matrix4 newModelMatrix =
        Matrix4.compose(newPosition, currentRotation, Vector3(1, 1, 1));
    await viewer.setCameraModelMatrix4(newModelMatrix);
  }

  void dispose() {
    _moveTimer?.cancel();
  }
}