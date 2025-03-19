import 'package:thermion_dart/src/filament/src/layers.dart';
import 'package:thermion_dart/thermion_dart.dart';

enum Projection { Perspective, Orthographic }

abstract class Camera {
  
  Future lookAt(Vector3 position, {Vector3? focus, Vector3? up}) async {
    focus ??= Vector3.zero();
    up ??= Vector3(0, 1, 0);
    final viewMatrix = makeViewMatrix(position, focus, up);
    viewMatrix.invert();
    await setModelMatrix(viewMatrix);
  }

  ///
  /// Sets the camera exposure.
  ///
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity);

  Future setProjection(Projection projection, double left, double right,
      double bottom, double top, double near, double far);
  Future setProjectionMatrixWithCulling(
      Matrix4 projectionMatrix, double near, double far);

  Future setLensProjection(
      {double near = kNear,
      double far = kFar,
      double aspect = 1.0,
      double focalLength = kFocalLength});

  Future<Matrix4> getViewMatrix();
  Future<Matrix4> getModelMatrix();
  Future<Matrix4> getProjectionMatrix();
  Future<Matrix4> getCullingProjectionMatrix();
  Future setModelMatrix(Matrix4 matrix);

  ThermionEntity getEntity();

  Future setTransform(Matrix4 transform);

  Future<double> getNear();
  Future<double> getCullingFar();
  Future<double> getFocalLength();
  Future<double> getFocusDistance();
  Future setFocusDistance(double focusDistance);

  Future destroy();
}
