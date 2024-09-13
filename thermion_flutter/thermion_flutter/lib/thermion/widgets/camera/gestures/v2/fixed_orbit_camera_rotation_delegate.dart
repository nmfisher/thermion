import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class FixedOrbitRotateCameraDelegate implements RotateCameraDelegate {
  final ThermionViewer viewer;
  static final _up = Vector3(0, 1, 0);
  static final _forward = Vector3(0, 0, -1);

  static const double _rotationSensitivity = 0.01;

  FixedOrbitRotateCameraDelegate(this.viewer);

  @override
  Future<void> rotateCamera(Offset delta, Vector2? velocity) async {
    double deltaX = delta.dx;
    double deltaY = delta.dy;
    deltaX *= _rotationSensitivity * viewer.pixelRatio;
    deltaY *= _rotationSensitivity * viewer.pixelRatio;

    Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
    Vector3 currentPosition = currentModelMatrix.getTranslation();
    double distance = currentPosition.length;
    Quaternion currentRotation =
        Quaternion.fromRotation(currentModelMatrix.getRotation());

    Quaternion yawRotation = Quaternion.axisAngle(_up, -deltaX);
    Vector3 right = _up.cross(_forward)..normalize();
    Quaternion pitchRotation = Quaternion.axisAngle(right, -deltaY);

    Quaternion newRotation = currentRotation * yawRotation * pitchRotation;
    newRotation.normalize();

    Vector3 newPosition = _forward.clone()
      ..applyQuaternion(newRotation)
      ..scale(-distance);

    Matrix4 newModelMatrix =
        Matrix4.compose(newPosition, newRotation, Vector3(1, 1, 1));
    await viewer.setCameraModelMatrix4(newModelMatrix);
  }
}
