import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/src/services/keyboard_key.g.dart';
import 'package:flutter/widgets.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/default_zoom_camera_delegate.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class FixedOrbitRotateCameraDelegate implements CameraDelegate {
  final ThermionViewer viewer;

  double rotationSensitivity = 0.01;

  late DefaultZoomCameraDelegate _zoomCameraDelegate;

  Offset _accumulatedRotationDelta = Offset.zero;
  double _accumulatedZoomDelta = 0.0;

  static final _up = Vector3(0, 1, 0);

  Timer? _updateTimer;

  Vector3 _targetPosition = Vector3(0, 0, 0);

  double? Function(Vector3)? getDistanceToTarget;

  FixedOrbitRotateCameraDelegate(this.viewer,
      {this.getDistanceToTarget,
      double? rotationSensitivity,
      double zoomSensitivity = 0.005}) {
    _zoomCameraDelegate = DefaultZoomCameraDelegate(this.viewer,
        zoomSensitivity: zoomSensitivity,
        getDistanceToTarget: getDistanceToTarget);
    this.rotationSensitivity = rotationSensitivity ?? 0.01;
    _startUpdateTimer();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _applyAccumulatedUpdates();
    });
  }

  void dispose() {
    _updateTimer?.cancel();
  }

  @override
  Future<void> rotate(Offset delta, Vector2? velocity) async {
    _accumulatedRotationDelta += delta;
  }

  @override
  Future<void> pan(Offset delta, Vector2? velocity) {
    throw UnimplementedError("Not supported in fixed orbit mode");
  }

  @override
  Future<void> zoom(double yScrollDeltaInPixels, Vector2? velocity) async {
    if (yScrollDeltaInPixels > 1) {
      _accumulatedZoomDelta++;
    } else {
      _accumulatedZoomDelta--;
    }
  }

  Future<void> _applyAccumulatedUpdates() async {
    if (_accumulatedRotationDelta.distanceSquared == 0.0 &&
        _accumulatedZoomDelta == 0.0) {
      return;
    }

    var modelMatrix = await viewer.getCameraModelMatrix();
    Vector3 cameraPosition = modelMatrix.getTranslation();

    final heightAboveSurface = getDistanceToTarget?.call(cameraPosition) ?? 1.0;

    final sphereRadius = cameraPosition.length - heightAboveSurface;

    // Apply rotation
    if (_accumulatedRotationDelta.distanceSquared > 0) {
      // Calculate the distance factor
      final distanceFactor = sqrt((heightAboveSurface / sphereRadius) + 1);

      // Adjust the base angle per meter
      final baseAnglePerMeter = 10000 / sphereRadius;
      final adjustedAnglePerMeter = baseAnglePerMeter * distanceFactor;

      final metersOnSurface = _accumulatedRotationDelta;
      final rotationX = metersOnSurface.dy * adjustedAnglePerMeter;
      final rotationY = metersOnSurface.dx * adjustedAnglePerMeter;

      Matrix4 rotation = Matrix4.rotationX(rotationX)..rotateY(rotationY);
      Vector3 newPos = rotation.getRotation() * cameraPosition;
      cameraPosition = newPos;
    }

    // Normalize the position to maintain constant distance from center
    cameraPosition =
        cameraPosition.normalized() * (sphereRadius + heightAboveSurface);

    // Apply zoom (modified to ensure minimum 10m distance)
    if (_accumulatedZoomDelta != 0.0) {
      var zoomFactor = -0.5 * _accumulatedZoomDelta;

      double newHeight = heightAboveSurface * (1 - zoomFactor);
      newHeight = newHeight.clamp(
          10.0, double.infinity); // Prevent getting closer than 10m to surface
      cameraPosition = cameraPosition.normalized() * (sphereRadius + newHeight);

      _accumulatedZoomDelta = 0.0;
    }

    // Ensure minimum 10m distance even after rotation
    final currentHeight = cameraPosition.length - sphereRadius;
    if (currentHeight < 10.0) {
      cameraPosition = cameraPosition.normalized() * (sphereRadius + 10.0);
    }

    // Calculate view matrix (unchanged)
    Vector3 forward = cameraPosition.normalized();
    Vector3 up = Vector3(0, 1, 0);
    final right = up.cross(forward)..normalize();
    up = forward.cross(right);

    Matrix4 viewMatrix = makeViewMatrix(cameraPosition, Vector3.zero(), up);
    viewMatrix.invert();

    // Set the camera model matrix
    await viewer.setCameraModelMatrix4(viewMatrix);
    _accumulatedRotationDelta = Offset.zero;
  }

  @override
  Future<void> onKeyRelease(PhysicalKeyboardKey key) async {
    // Ignore
  }

  @override
  Future<void> onKeypress(PhysicalKeyboardKey key) async {
    // Ignore
  }
}
