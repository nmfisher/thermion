import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/src/gestures/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class DefaultZoomCameraDelegate {
  final ThermionViewer viewer;
  final double zoomSensitivity;

  final double? Function(Vector3 cameraPosition)? getDistanceToTarget;

  DefaultZoomCameraDelegate(this.viewer,
      {this.zoomSensitivity = 0.005, this.getDistanceToTarget});

  ///
  /// Converts the given [scrollDelta] (usually somewhere between 1 and -1) to
  /// a percentage of the current camera distance (either to the origin,
  /// or to a custom target) along its forward vector.
  /// In other words, "shift "
  ///
  double calculateZoomFactor(
      double scrollDelta, Vector2? velocity) {
    double zoomFactor = scrollDelta * zoomSensitivity;
    if (zoomFactor.abs() < 0.0001) {
      zoomFactor = scrollDelta * zoomSensitivity;
    }
    return zoomFactor;
  }

  @override
  Future<void> zoom(double scrollDelta, Vector2? velocity) async {
    Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
    final cameraRotation = currentModelMatrix.getRotation();
    final cameraPosition = currentModelMatrix.getTranslation();

    Vector3 forwardVector = cameraRotation.getColumn(2);
    forwardVector.normalize();

    var zoomDistance =
        calculateZoomFactor(scrollDelta, velocity);

    Vector3 newPosition = cameraPosition + (forwardVector * zoomDistance);
    await viewer.setCameraPosition(newPosition.x, newPosition.y, newPosition.z);
  }
}
