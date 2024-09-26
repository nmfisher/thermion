import 'dart:async';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_dart/thermion_dart/input/src/delegates.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/shared_types/camera.dart';
import '../input_handler.dart';

class FixedOrbitRotateInputHandlerDelegate implements InputHandlerDelegate {
  final ThermionViewer viewer;
  late Future<Camera> _camera;
  final double minimumDistance;
  double? Function(Vector3)? getDistanceToTarget;

  Vector2 _queuedRotationDelta = Vector2.zero();
  double _queuedZoomDelta = 0.0;

  static final _up = Vector3(0, 1, 0);
  Timer? _updateTimer;

  FixedOrbitRotateInputHandlerDelegate(
    this.viewer, {
    this.getDistanceToTarget,
    this.minimumDistance = 10.0,
  }) {
    _camera = viewer.getMainCamera();
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
        _queuedZoomDelta += delta!.z;
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

  @override
  Future<void> execute() async {
    if (_queuedRotationDelta.length2 == 0.0 && _queuedZoomDelta == 0.0) {
      return;
    }

    var viewMatrix = await viewer.getCameraViewMatrix();
    var modelMatrix = await viewer.getCameraModelMatrix();
    var projectionMatrix = await viewer.getCameraProjectionMatrix();
    var inverseProjectionMatrix = projectionMatrix.clone()..invert();
    Vector3 currentPosition = modelMatrix.getTranslation();

    Vector3 forward = -currentPosition.normalized();
    Vector3 right = _up.cross(forward).normalized();
    Vector3 up = forward.cross(right);

    // Calculate intersection point and depth
    double radius = getDistanceToTarget?.call(currentPosition) ?? 1.0;
    if (radius != 1.0) {
      radius = currentPosition.length - radius;
    }
    Vector3 intersection = (-forward).scaled(radius);

    final intersectionInViewSpace = viewMatrix *
        Vector4(intersection.x, intersection.y, intersection.z, 1.0);
    final intersectionInClipSpace = projectionMatrix * intersectionInViewSpace;
    final intersectionInNdcSpace =
        intersectionInClipSpace / intersectionInClipSpace.w;

    // Calculate new camera position based on rotation
    final ndcX = 2 *
        ((-_queuedRotationDelta.x * viewer.pixelRatio) /
            viewer.viewportDimensions.$1);
    final ndcY = 2 *
        ((_queuedRotationDelta.y * viewer.pixelRatio) /
            viewer.viewportDimensions.$2);
    final ndc = Vector4(ndcX, ndcY, intersectionInNdcSpace.z, 1.0);

    var clipSpace = Vector4(
        ndc.x * intersectionInClipSpace.w,
        ndcY * intersectionInClipSpace.w,
        ndc.z * intersectionInClipSpace.w,
        intersectionInClipSpace.w);
    Vector4 cameraSpace = inverseProjectionMatrix * clipSpace;
    Vector4 worldSpace = modelMatrix * cameraSpace;

    var worldSpace3 = worldSpace.xyz.normalized() * currentPosition.length;
    currentPosition = worldSpace3;

    // Apply zoom
    if (_queuedZoomDelta != 0.0) {
      Vector3 toSurface = currentPosition - intersection;
      currentPosition =
          currentPosition + toSurface.scaled(_queuedZoomDelta * 0.1);
    }

    // Ensure minimum distance
    if (currentPosition.length < radius + minimumDistance) {
      currentPosition =
          (currentPosition.normalized() * (radius + minimumDistance));
    }

    // Calculate view matrix
    forward = -currentPosition.normalized();
    right = _up.cross(forward).normalized();
    up = forward.cross(right);

    Matrix4 newViewMatrix = makeViewMatrix(currentPosition, Vector3.zero(), up);
    newViewMatrix.invert();

    // Set the camera model matrix
    var camera = await _camera;
    await camera.setModelMatrix(newViewMatrix);

    // Reset queued deltas
    _queuedRotationDelta = Vector2.zero();
    _queuedZoomDelta = 0.0;
  }
}
