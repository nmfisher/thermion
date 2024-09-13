import 'dart:ui';

import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class DefaultPanCameraDelegate implements PanCameraDelegate {
  final ThermionViewer viewer;

  static const double _panSensitivity = 0.005;

  DefaultPanCameraDelegate(this.viewer);

  @override
  Future<void> panCamera(Offset delta, Vector2? velocity) async {
    double deltaX = delta.dx;
    double deltaY = delta.dy;
    deltaX *= _panSensitivity * viewer.pixelRatio;
    deltaY *= _panSensitivity * viewer.pixelRatio;

    Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
    Vector3 currentPosition = currentModelMatrix.getTranslation();
    Quaternion currentRotation = Quaternion.fromRotation(currentModelMatrix.getRotation());

    Vector3 right = Vector3(1, 0, 0)..applyQuaternion(currentRotation);
    Vector3 up = Vector3(0, 1, 0)..applyQuaternion(currentRotation);

    Vector3 panOffset = right * -deltaX + up * deltaY;
    Vector3 newPosition = currentPosition + panOffset;

    Matrix4 newModelMatrix = Matrix4.compose(newPosition, currentRotation, Vector3(1, 1, 1));
    await viewer.setCameraModelMatrix4(newModelMatrix);
  }
}