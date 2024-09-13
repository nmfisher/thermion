import 'dart:async';
import 'dart:ui';

import 'package:flutter/src/services/keyboard_key.g.dart';
import 'package:flutter/widgets.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/default_zoom_camera_delegate.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class FixedOrbitRotateCameraDelegate implements CameraDelegate {
  final ThermionViewer viewer;
  static final _up = Vector3(0, 1, 0);
  static final _forward = Vector3(0, 0, -1);
  static final Vector3 _right = Vector3(1, 0, 0);

  static const double _rotationSensitivity = 0.01;

  late DefaultZoomCameraDelegate _zoomCameraDelegate;

  Offset _accumulatedRotationDelta = Offset.zero;
  double _accumulatedZoomDelta = 0.0;
  
  Timer? _updateTimer;
  
  FixedOrbitRotateCameraDelegate(this.viewer) {
    _zoomCameraDelegate = DefaultZoomCameraDelegate(this.viewer);
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
  Future<void> zoom(double scrollDelta, Vector2? velocity) async {
    _accumulatedZoomDelta += scrollDelta;
  }

  Future<void> _applyAccumulatedUpdates() async {
    if (_accumulatedRotationDelta != Offset.zero || _accumulatedZoomDelta != 0.0) {
      Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
      Vector3 currentPosition = currentModelMatrix.getTranslation();
      double distance = currentPosition.length;
      Quaternion currentRotation =
          Quaternion.fromRotation(currentModelMatrix.getRotation());

      // Apply rotation
      if (_accumulatedRotationDelta != Offset.zero) {
        double deltaX = _accumulatedRotationDelta.dx * _rotationSensitivity * viewer.pixelRatio;
        double deltaY = _accumulatedRotationDelta.dy * _rotationSensitivity * viewer.pixelRatio;

        Quaternion yawRotation = Quaternion.axisAngle(_up, -deltaX);
        Quaternion pitchRotation = Quaternion.axisAngle(_right, -deltaY);

        currentRotation = currentRotation * yawRotation * pitchRotation;
        currentRotation.normalize();

        _accumulatedRotationDelta = Offset.zero;
      }

      // Apply zoom
      if (_accumulatedZoomDelta != 0.0) {
        var zoomDistance = _zoomCameraDelegate.calculateZoomDistance(
          _accumulatedZoomDelta, 
          null, 
          Vector3.zero()
        );
        distance += zoomDistance;
        distance = distance.clamp(0.1, 1000.0); // Adjust these limits as needed

        _accumulatedZoomDelta = 0.0;
      }

      // Calculate new position
      Vector3 newPosition = _forward.clone()
        ..applyQuaternion(currentRotation)
        ..scale(-distance);

      // Create and set new model matrix
      Matrix4 newModelMatrix =
          Matrix4.compose(newPosition, currentRotation, Vector3(1, 1, 1));
      await viewer.setCameraModelMatrix4(newModelMatrix);
    }
  }

  @override
  Future<void> onKeyRelease(PhysicalKeyboardKey key) async {
    //ignore
  }

  @override
  Future<void> onKeypress(PhysicalKeyboardKey key) async  {
    //ignore
  }
}