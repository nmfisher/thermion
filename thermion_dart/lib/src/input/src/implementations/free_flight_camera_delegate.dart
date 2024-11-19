import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/viewer.dart';
import '../delegates.dart';
import '../input_handler.dart';

class FreeFlightInputHandlerDelegate implements InputHandlerDelegate {
  final ThermionViewer viewer;
  late Future<ThermionEntity> entity;
  final Vector3? minBounds;
  final Vector3? maxBounds;
  final double rotationSensitivity;
  final double movementSensitivity;
  final double zoomSensitivity;
  final double panSensitivity;
  final double? clampY;

  Vector2 _queuedRotationDelta = Vector2.zero();
  Vector3 _queuedTranslateDelta = Vector3.zero();
  double _queuedZoomDelta = 0.0;
  Vector3 _queuedMoveDelta = Vector3.zero();

  FreeFlightInputHandlerDelegate(this.viewer,
      {this.minBounds,
      this.maxBounds,
      this.rotationSensitivity = 0.001,
      this.movementSensitivity = 0.1,
      this.zoomSensitivity = 0.1,
      this.panSensitivity = 0.1,
      this.clampY,
      ThermionEntity? entity}) {
    if (entity != null) {
      this.entity = Future.value(entity);
    } else {
      this.entity = viewer.getMainCameraEntity();
    }
  }

  @override
  Future<void> queue(InputAction action, Vector3? delta) async {
    if (delta == null) return;

    switch (action) {
      case InputAction.ROTATE:
        _queuedRotationDelta += Vector2(delta.x, delta.y);
        break;
      case InputAction.TRANSLATE:
        _queuedTranslateDelta += delta;
        break;
      case InputAction.PICK:
        _queuedZoomDelta += delta.z;
        break;
      case InputAction.NONE:
        break;
      case InputAction.ZOOM:
        _queuedZoomDelta += delta.z;
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
        _queuedTranslateDelta.length2 == 0.0 &&
        _queuedZoomDelta == 0.0 &&
        _queuedMoveDelta.length2 == 0.0) {
      _executing = false;
      return;
    }

    final activeCamera = await viewer.getActiveCamera();

    Matrix4 current = await viewer.getLocalTransform(await entity);

    Vector3 relativeTranslation = Vector3.zero();
    Quaternion relativeRotation = Quaternion.identity();

    if (_queuedRotationDelta.length2 > 0.0) {
      double deltaX = _queuedRotationDelta.x * rotationSensitivity;
      double deltaY = _queuedRotationDelta.y * rotationSensitivity;
      relativeRotation = Quaternion.axisAngle(current.up, -deltaX) * Quaternion.axisAngle(current.right, -deltaY);
      _queuedRotationDelta = Vector2.zero();
    }

    // Apply (mouse) pan
    if (_queuedTranslateDelta.length2 > 0.0) {
      double deltaX = _queuedTranslateDelta.x * panSensitivity;
      double deltaY = _queuedTranslateDelta.y * panSensitivity;
      double deltaZ = -_queuedTranslateDelta.z * panSensitivity;

      relativeTranslation += current.right * deltaX +
          current.up * deltaY +
          current.forward * deltaZ;
      _queuedTranslateDelta = Vector3.zero();
    }

    // Apply zoom
    if (_queuedZoomDelta != 0.0) {
      relativeTranslation += current.forward
        ..scaled(_queuedZoomDelta * zoomSensitivity);
      _queuedZoomDelta = 0.0;
    }

    // Apply queued movement
    if (_queuedMoveDelta.length2 > 0.0) {
      relativeTranslation += (current.right * _queuedMoveDelta.x +
              current.up * _queuedMoveDelta.y +
              current.forward * _queuedMoveDelta.z) *
          movementSensitivity;

      _queuedMoveDelta = Vector3.zero();
    }

    // If the managed entity is not the active camera, we need to apply the rotation from the current camera model matrix
    // to the entity's translation
    if (await entity != activeCamera.getEntity()) {
      Matrix4 modelMatrix = await activeCamera.getModelMatrix();
      relativeTranslation = modelMatrix.getRotation() * relativeTranslation;
    }

    await viewer.setTransform(
        await entity,
        
            Matrix4.compose(
                relativeTranslation, relativeRotation, Vector3(1, 1, 1)) * current );

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

    if (clampY != null) {
      position.y = clampY!;
    }
    return position;
  }
}
