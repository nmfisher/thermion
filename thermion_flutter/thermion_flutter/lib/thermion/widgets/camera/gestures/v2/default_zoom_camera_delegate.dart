import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class DefaultZoomCameraDelegate {
  final ThermionViewer viewer;
  final double zoomSensitivity;

  final double? Function(Vector3 cameraPosition)? getDistanceToTarget;

  DefaultZoomCameraDelegate(this.viewer,
      {this.zoomSensitivity = 0.005, this.getDistanceToTarget});

  double calculateZoomDistance(double scrollDelta, Vector2? velocity, Vector3 cameraPosition) {
    double? distanceToTarget = getDistanceToTarget?.call(cameraPosition);
    double zoomDistance = scrollDelta * zoomSensitivity;
    if (distanceToTarget != null) {
      zoomDistance *= distanceToTarget;
      if (zoomDistance.abs() < 0.0001) {
        zoomDistance = scrollDelta * zoomSensitivity;
      }
    }
    return max(zoomDistance, scrollDelta * zoomSensitivity);
  }

  @override
  Future<void> zoom(double scrollDelta, Vector2? velocity) async {
    Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
    final cameraRotation = currentModelMatrix.getRotation();
    final cameraPosition = currentModelMatrix.getTranslation();

    Vector3 forwardVector = cameraRotation.getColumn(2);
    forwardVector.normalize();

    var zoomDistance =
        calculateZoomDistance(scrollDelta, velocity, cameraPosition);

    Vector3 newPosition = cameraPosition + (forwardVector * zoomDistance);
    await viewer.setCameraPosition(newPosition.x, newPosition.y, newPosition.z);
  }
}
