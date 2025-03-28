import 'dart:async';
import 'package:vector_math/vector_math_64.dart';

import '../../../viewer/viewer.dart';
import '../../input.dart';

///
/// An [InputHandlerDelegate] that orbits the camera around a fixed
/// point.
///
class FixedOrbitRotateInputHandlerDelegate implements InputHandlerDelegate {
  final View view;
  final double minimumDistance;
  late final Vector3 target;

  final double rotationSensitivity;
  final double zoomSensitivity;

  Vector2 _queuedRotationDelta = Vector2.zero();
  double _queuedZoomDelta = 0.0;

  Timer? _updateTimer;

  FixedOrbitRotateInputHandlerDelegate(
    this.view, {
    Vector3? target,
    this.minimumDistance = 10.0,
    this.rotationSensitivity = 0.01,
    this.zoomSensitivity = 0.1,
  }) {
    this.target = target ?? Vector3.zero();

    view.getCamera().then((camera) {
      camera.lookAt(Vector3(0.0, 0, -minimumDistance),
          focus: this.target, up: Vector3(0.0, 1.0, 0.0));
    });
  }

  void dispose() {
    _updateTimer?.cancel();
  }

  @override
  Future<void> queue(InputAction action, Vector3? delta) async {
    if (delta == null) return;

    switch (action) {
      case InputAction.ROTATE:
        _queuedRotationDelta += Vector2(delta.x, delta.y);
        break;
      case InputAction.TRANSLATE:
        _queuedZoomDelta += delta.z;
        break;
      case InputAction.PICK:
        break;
      case InputAction.NONE:
        // Do nothing
        break;
      case InputAction.ZOOM:
        _queuedZoomDelta += delta.z;
        break;
    }
  }

  bool _executing = false;

  @override
  Future<Matrix4?> execute() async {
    if (_queuedRotationDelta.length2 == 0.0 && _queuedZoomDelta == 0.0) {
      return null;
    }

    if (_executing) {
      return null;
    }

    _executing = true;

    final camera = await view.getCamera();

    final viewport = await view.getViewport();

    var viewMatrix = await camera.getViewMatrix();
    var modelMatrix = await camera.getModelMatrix();
    var projectionMatrix = await camera.getProjectionMatrix();
    var inverseProjectionMatrix = projectionMatrix.clone()..invert();
    Vector3 currentPosition = modelMatrix.getTranslation();

    Vector3 forward = modelMatrix.forward;

    if (forward.length == 0) {
      forward = Vector3(0, 0, -1);
      currentPosition = Vector3(0, 0, minimumDistance);
    }

    Matrix4? updatedModelMatrix = null;

    // Zoom
    if (_queuedZoomDelta != 0.0) {
      var newPosition = currentPosition +
          (currentPosition - target).scaled(_queuedZoomDelta * zoomSensitivity);

      var distToTarget = (newPosition - target).length;

      // if we somehow overshot the minimum distance, reset the camera to the minimum distance
      if (distToTarget >= minimumDistance) {
        currentPosition = newPosition;
        // Calculate view matrix
        forward = (currentPosition - target).normalized();
        var right = modelMatrix.up.cross(forward).normalized();
        var up = forward.cross(right);

        Matrix4 newViewMatrix = makeViewMatrix(currentPosition, target, up);
        newViewMatrix.invert();

        await camera.setModelMatrix(newViewMatrix);
        updatedModelMatrix = newViewMatrix;
      }
    } else if (_queuedRotationDelta.length != 0) {
      double rotateX = _queuedRotationDelta.x * rotationSensitivity;
      double rotateY = _queuedRotationDelta.y * rotationSensitivity;

      var modelMatrix = await camera.getModelMatrix();

      // for simplicity, we always assume a fixed coordinate system where
      // we are rotating around world Y and camera X
      var rot1 = Matrix4.identity()
        ..setRotation(Quaternion.axisAngle(Vector3(0, 1, 0), -rotateX)
            .asRotationMatrix());
      var rot2 = Matrix4.identity()
        ..setRotation(Quaternion.axisAngle(modelMatrix.right, rotateY)
            .asRotationMatrix());

      modelMatrix = rot1 * rot2 * modelMatrix;
      await camera.setModelMatrix(modelMatrix);
      updatedModelMatrix = modelMatrix;
    }

    // Reset queued deltas
    _queuedRotationDelta = Vector2.zero();
    _queuedZoomDelta = 0.0;

    _executing = false;
    return updatedModelMatrix;
  }
}
