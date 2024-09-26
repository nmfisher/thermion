import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/viewer.dart';
import '../delegates.dart';
import '../input_handler.dart';

class FreeFlightInputHandlerDelegate implements InputHandlerDelegate {
  
  final ThermionViewer viewer;
  final Vector3? minBounds;
  final Vector3? maxBounds;
  final double rotationSensitivity;
  final double movementSensitivity;
  final double zoomSensitivity;
  final double panSensitivity;

  static final _up = Vector3(0, 1, 0);
  static final _forward = Vector3(0, 0, -1);
  static final Vector3 _right = Vector3(1, 0, 0);

  Vector2 _queuedRotationDelta = Vector2.zero();
  Vector2 _queuedPanDelta = Vector2.zero();
  double _queuedZoomDelta = 0.0;
  Vector3 _queuedMoveDelta = Vector3.zero();

  FreeFlightInputHandlerDelegate(
    this.viewer, {
    this.minBounds,
    this.maxBounds,
    this.rotationSensitivity = 0.001,
    this.movementSensitivity = 0.1,
    this.zoomSensitivity = 0.1,
    this.panSensitivity = 0.1,
  });

  @override
  Future<void> queue(InputAction action, Vector3? delta) async {
    if (delta == null) return;

    switch (action) {
      case InputAction.ROTATE:
        _queuedRotationDelta += Vector2(delta.x, delta.y);
        break;
      case InputAction.TRANSLATE:
        _queuedPanDelta += Vector2(delta.x, delta.y);
        _queuedZoomDelta += delta.z;
        break;
      case InputAction.PICK:
        // Assuming PICK is used for zoom in this context
        _queuedZoomDelta += delta.z;
        break;
      case InputAction.NONE:
        // Do nothing
        break;
    }
  }

  bool _executing = false;

  @override
  Future<void> execute() async {
    if (_executing) {
      return;
    }

    _executing = true;

    if (_queuedRotationDelta.length2 == 0.0 &&
        _queuedPanDelta.length2 == 0.0 &&
        _queuedZoomDelta == 0.0 &&
        _queuedMoveDelta.length2 == 0.0) {
      _executing = false;
      return;
    }

    Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
    Vector3 currentPosition = currentModelMatrix.getTranslation();
    Quaternion currentRotation =
        Quaternion.fromRotation(currentModelMatrix.getRotation());

    // Apply rotation
    if (_queuedRotationDelta.length2 > 0.0) {
      double deltaX =
          _queuedRotationDelta.x * rotationSensitivity * viewer.pixelRatio;
      double deltaY =
          _queuedRotationDelta.y * rotationSensitivity * viewer.pixelRatio;

      Quaternion yawRotation = Quaternion.axisAngle(_up, -deltaX);
      Quaternion pitchRotation = Quaternion.axisAngle(_right, -deltaY);

      currentRotation = currentRotation * pitchRotation * yawRotation;
      currentRotation.normalize();

      _queuedRotationDelta = Vector2.zero();
    }

    // Apply pan
    if (_queuedPanDelta.length2 > 0.0) {
      Vector3 right = _right.clone()..applyQuaternion(currentRotation);
      Vector3 up = _up.clone()..applyQuaternion(currentRotation);

      double deltaX = _queuedPanDelta.x * panSensitivity * viewer.pixelRatio;
      double deltaY = _queuedPanDelta.y * panSensitivity * viewer.pixelRatio;

      Vector3 panOffset = right * deltaX + up * deltaY;
      currentPosition += panOffset;

      _queuedPanDelta = Vector2.zero();
    }

    // Apply zoom
    if (_queuedZoomDelta != 0.0) {
      Vector3 forward = _forward.clone()..applyQuaternion(currentRotation);
      currentPosition += forward * -_queuedZoomDelta * zoomSensitivity;
      _queuedZoomDelta = 0.0;
    }

    // Apply queued movement
    if (_queuedMoveDelta.length2 > 0.0) {
      Vector3 forward = _forward.clone()..applyQuaternion(currentRotation);
      Vector3 right = _right.clone()..applyQuaternion(currentRotation);
      Vector3 up = _up.clone()..applyQuaternion(currentRotation);

      Vector3 moveOffset = right * _queuedMoveDelta.x +
          up * _queuedMoveDelta.y +
          forward * _queuedMoveDelta.z;
      currentPosition += moveOffset;

      _queuedMoveDelta = Vector3.zero();
    }

    // Constrain position
    currentPosition = _constrainPosition(currentPosition);

    // Update camera
    Matrix4 newModelMatrix =
        Matrix4.compose(currentPosition, currentRotation, Vector3(1, 1, 1));
    await viewer.setCameraModelMatrix4(newModelMatrix);

    _executing = false;
  }

  Vector3 _constrainPosition(Vector3 position) {
    if (minBounds != null) {
      position.x = position.x.clamp(minBounds!.x, double.infinity);
      position.y = position.y.clamp(minBounds!.y, double.infinity);
      position.z = position.z.clamp(minBounds!.z, double.infinity);
    }
    if (maxBounds != null) {
      position.x = position.x.clamp(double.negativeInfinity, maxBounds!.x);
      position.y = position.y.clamp(double.negativeInfinity, maxBounds!.y);
      position.z = position.z.clamp(double.negativeInfinity, maxBounds!.z);
    }
    return position;
  }
}
