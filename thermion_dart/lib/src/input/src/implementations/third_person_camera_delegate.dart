import 'dart:async';
import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/viewer.dart';
import '../delegates.dart';
import '../input_handler.dart';

class OverTheShoulderCameraDelegate implements InputHandlerDelegate {
  final ThermionViewer viewer;

  late ThermionEntity player;
  late Camera camera;

  final double rotationSensitivity;
  final double movementSensitivity;
  final double zoomSensitivity;
  final double panSensitivity;
  final double? clampY;

  static final _up = Vector3(0, 1, 0);
  static final _forward = Vector3(0, 0, -1);
  static final Vector3 _right = Vector3(1, 0, 0);

  Vector2 _queuedRotationDelta = Vector2.zero();
  double _queuedZoomDelta = 0.0;
  Vector3 _queuedMoveDelta = Vector3.zero();

  final cameraPosition = Vector3(-0.5, 2.5, -3);
  final cameraUp = Vector3(0, 1, 0);
  var cameraLookAt = Vector3(0, 0.5, 3);

  final void Function(Matrix4 transform)? onUpdate;

  OverTheShoulderCameraDelegate(this.viewer, this.player, this.camera,
      {this.rotationSensitivity = 0.001,
      this.movementSensitivity = 0.1,
      this.zoomSensitivity = 0.1,
      this.panSensitivity = 0.1,
      this.clampY,
      ThermionEntity? entity,
      this.onUpdate}) {}

  @override
  Future<void> queue(InputAction action, Vector3? delta) async {
    if (delta == null) return;

    switch (action) {
      case InputAction.ROTATE:
        _queuedRotationDelta += Vector2(delta.x, delta.y);
        break;
      case InputAction.TRANSLATE:
        _queuedMoveDelta += delta;
        break;
      case InputAction.PICK:
        _queuedZoomDelta += delta.z;
        break;
      case InputAction.NONE:
        break;
    }
  }

  static bool _executing = false;
  static bool get executing => _executing;

  @override
  Future<void> execute() async {
    if (_executing) {
      return;
    }

    _executing = true;

    if (_queuedRotationDelta.length2 == 0.0 &&
        _queuedZoomDelta == 0.0 &&
        _queuedMoveDelta.length2 == 0.0) {
      _executing = false;
      return;
    }

    Matrix4 currentPlayerTransform = await viewer.getWorldTransform(player);

    // first we need to convert the move vector to player space
    var newTransform =
        Matrix4.translation(_queuedMoveDelta * movementSensitivity);

    _queuedMoveDelta = Vector3.zero();
    Matrix4 newPlayerTransform = newTransform * currentPlayerTransform;
    await viewer.setTransform(player, newPlayerTransform);

    if (_queuedZoomDelta != 0.0) {
      // Ignore zoom
    }

    var inverted = newPlayerTransform.clone()..invert();

    // camera is always looking at -Z, whereas models generally face towards +Z
    if (_queuedRotationDelta.length2 > 0.0) {
      double deltaX =
          _queuedRotationDelta.x * rotationSensitivity * viewer.pixelRatio;
      double deltaY =
          _queuedRotationDelta.y * rotationSensitivity * viewer.pixelRatio;

      cameraLookAt = Matrix4.rotationY(-deltaX) *
          Matrix4.rotationX(-deltaY) *
          cameraLookAt;
      _queuedRotationDelta = Vector2.zero();
    }

    var newCameraViewMatrix =
        makeViewMatrix(cameraPosition, cameraLookAt, cameraUp);
    newCameraViewMatrix.invert();
    var newCameraTransform = newPlayerTransform * newCameraViewMatrix;
    await camera.setTransform(newCameraTransform);

    await viewer.queueTransformUpdates(
        [camera.getEntity(), player], [newCameraTransform, newPlayerTransform]);
    onUpdate?.call(newPlayerTransform);
    _executing = false;
  }
}
