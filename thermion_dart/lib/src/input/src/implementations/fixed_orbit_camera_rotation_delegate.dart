import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/src/shared_types/camera.dart';
import '../../../viewer/viewer.dart';
import '../../input.dart';
import '../input_handler.dart';

class FixedOrbitRotateInputHandlerDelegate implements InputHandlerDelegate {
  final ThermionViewer viewer;
  late Future<Camera> _camera;
  final double minimumDistance;
  Future<double?> Function(Vector3)? getDistanceToTarget;

  Vector2 _queuedRotationDelta = Vector2.zero();
  double _queuedZoomDelta = 0.0;

  static final _up = Vector3(0, 1, 0);
  Timer? _updateTimer;

  FixedOrbitRotateInputHandlerDelegate(
    this.viewer, {
    this.getDistanceToTarget,
    this.minimumDistance = 10.0,
  }) {
    _camera = viewer.getMainCamera().then((Camera cam) async {
      var viewMatrix = makeViewMatrix(Vector3(0.0, 0, -minimumDistance),
          Vector3.zero(), Vector3(0.0, 1.0, 0.0));
      viewMatrix.invert();

      await cam.setTransform(viewMatrix);
      return cam;
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
    if (_queuedRotationDelta.length2 == 0.0 && _queuedZoomDelta == 0.0) {
      return;
    }

    if (_executing) {
      return;
    }

    _executing = true;

    final view = await viewer.getViewAt(0);
    final viewport = await view.getViewport();

    var viewMatrix = await viewer.getCameraViewMatrix();
    var modelMatrix = await viewer.getCameraModelMatrix();
    var projectionMatrix = await viewer.getCameraProjectionMatrix();
    var inverseProjectionMatrix = projectionMatrix.clone()..invert();
    Vector3 currentPosition = modelMatrix.getTranslation();

    Vector3 forward = -currentPosition.normalized();

    if (forward.length == 0) {
      forward = Vector3(0, 0, -1);
      currentPosition = Vector3(0, 0, minimumDistance);
    }

    Vector3 right = _up.cross(forward).normalized();
    Vector3 up = forward.cross(right);

    // Calculate the point where the camera forward ray intersects with the
    // surface of the target sphere
    var distanceToTarget =
        (await getDistanceToTarget?.call(currentPosition)) ?? 0;

    Vector3 intersection =
        (-forward).scaled(currentPosition.length - distanceToTarget);

    final intersectionInViewSpace = viewMatrix *
        Vector4(intersection.x, intersection.y, intersection.z, 1.0);
    final intersectionInClipSpace = projectionMatrix * intersectionInViewSpace;
    final intersectionInNdcSpace =
        intersectionInClipSpace / intersectionInClipSpace.w;

    // Calculate new camera position based on rotation
    final ndcX = 2 * ((-_queuedRotationDelta.x) / viewport.width);
    final ndcY = 2 * ((_queuedRotationDelta.y) / viewport.height);
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

    // Zoom
    if (_queuedZoomDelta != 0.0) {
      var distToIntersection =
          (currentPosition - intersection).length - minimumDistance;

      // if we somehow overshot the minimum distance, reset the camera to the minimum distance
      if (distToIntersection < 0) {
        currentPosition +=
            (intersection.normalized().scaled(-distToIntersection * 10));
      } else {
        bool zoomingOut = _queuedZoomDelta > 0;
        late Vector3 offset;

        // when zooming, we don't always use fractions of the distance from
        // the camera to the target (this is due to float precision issues at
        // large distances, and also it doesn't work well for UI).

        // if we're zooming out and the distance is less than 10m, we zoom out by 1 unit
        if (zoomingOut) {
          if (distToIntersection < 10) {
            offset = intersection.normalized();
          } else {
            offset = intersection.normalized().scaled(distToIntersection / 10);
          }
          // if we're zooming in and the distance is less than 5m, zoom in by 1/2 the distance,
          // otherwise 1/10 of the distance each time
        } else {
          if (distToIntersection < 5) {
            offset = intersection.normalized().scaled(-distToIntersection / 2);
          } else {
            offset = intersection.normalized().scaled(-distToIntersection / 10);
          }

          if (offset.length > distToIntersection) {
            offset = Vector3.zero();
          }
        }
        currentPosition += offset;
      }
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

    _executing = false;
  }
}
