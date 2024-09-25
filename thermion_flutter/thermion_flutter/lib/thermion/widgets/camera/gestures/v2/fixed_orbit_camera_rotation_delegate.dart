import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

/// A camera delegate that rotates the camera around the origin.
/// Panning is not permitted; zooming is permitted (up to a minimum distance)
///
/// The rotation sensitivity will be automatically adjusted so that
/// 100 horizontal pixels equates to a geodetic distance of 1m when the camera
/// is 1m from the surface (denoted by distanceToSurface). This scales to 10m
/// geodetic distance when the camera is 100m from the surface, 100m when the
/// camera is 1000m from the surface, and so on.
///
///
class FixedOrbitRotateCameraDelegate implements CameraDelegate {
  final ThermionViewer viewer;
  final double minimumDistance;
  double? Function(Vector3)? getDistanceToTarget;

  Offset _accumulatedRotationDelta = Offset.zero;
  double _accumulatedZoomDelta = 0.0;

  static final _up = Vector3(0, 1, 0);
  Timer? _updateTimer;

  FixedOrbitRotateCameraDelegate(
    this.viewer, {
    this.getDistanceToTarget,
    this.minimumDistance = 10.0,
  });

  void dispose() {
    _updateTimer?.cancel();
  }

  @override
  Future<void> rotate(Offset delta, Vector2? velocity) async {
    _accumulatedRotationDelta += delta;
    await _applyAccumulatedUpdates();
  }

  @override
  Future<void> pan(Offset delta, Vector2? velocity) {
    throw UnimplementedError("Not supported in fixed orbit mode");
  }

  @override
  Future<void> zoom(double yScrollDeltaInPixels, Vector2? velocity) async {
    _accumulatedZoomDelta += yScrollDeltaInPixels > 0 ? 1 : -1;
    await _applyAccumulatedUpdates();
  }

  Future<void> _applyAccumulatedUpdates() async {
    if (_accumulatedRotationDelta.distanceSquared == 0.0 &&
        _accumulatedZoomDelta == 0.0) {
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

    // first, we find the point in the sphere that intersects with the camera
    // forward vector
    double radius = 0.0;
    double? distanceToTarget = getDistanceToTarget?.call(currentPosition);
    if (distanceToTarget != null) {
      radius = currentPosition.length - distanceToTarget;
    } else {
      radius = 1.0;
    }
    Vector3 intersection = (-forward).scaled(radius);

    // next, calculate the depth value at that intersection point
    final intersectionInViewSpace = viewMatrix *
        Vector4(intersection.x, intersection.y, intersection.z, 1.0);
    final intersectionInClipSpace = projectionMatrix * intersectionInViewSpace;
    final intersectionInNdcSpace =
        intersectionInClipSpace / intersectionInClipSpace.w;

    // using that depth value, find the world space position of the mouse
    // note we flip the signs of the X and Y values

    final ndcX = 2 *
        ((-_accumulatedRotationDelta.dx * viewer.pixelRatio) /
            viewer.viewportDimensions.$1);
    final ndcY = 2 *
        ((_accumulatedRotationDelta.dy * viewer.pixelRatio) /
            viewer.viewportDimensions.$2);
    final ndc = Vector4(ndcX, ndcY, intersectionInNdcSpace.z, 1.0);

    var clipSpace = Vector4(
        ndc.x * intersectionInClipSpace.w,
        ndcY * intersectionInClipSpace.w,
        ndc.z * intersectionInClipSpace.w,
        intersectionInClipSpace.w);
    Vector4 cameraSpace = inverseProjectionMatrix * clipSpace;
    Vector4 worldSpace = modelMatrix * cameraSpace;

    // the new camera world space position will be that position,
    // scaled to the camera's current distance
    var worldSpace3 = worldSpace.xyz.normalized() * currentPosition.length;
    currentPosition = worldSpace3;

    // Apply zoom
    if (_accumulatedZoomDelta != 0.0) {
      // double zoomFactor = 1.0 + ();
      Vector3 toSurface = currentPosition - intersection;
      currentPosition = currentPosition + toSurface.scaled(_accumulatedZoomDelta * 0.1);
      _accumulatedZoomDelta = 0.0;
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
    await viewer.setCameraModelMatrix4(newViewMatrix);
    _accumulatedRotationDelta = Offset.zero;
  }

  @override
  Future<void> onKeyRelease(PhysicalKeyboardKey key) async {
    // Ignore
  }

  @override
  Future<void> onKeypress(PhysicalKeyboardKey key) async {
    // Ignore
  }
}
