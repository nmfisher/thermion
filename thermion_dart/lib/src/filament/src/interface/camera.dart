import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

enum Projection { Perspective, Orthographic }

abstract class Camera<T> extends NativeHandle {
  ///
  ///
  ///
  Future<Vector3> getPosition() async {
    final modelMatrix = await getModelMatrix();
    return modelMatrix.getTranslation();
  }

  ///
  ///
  ///
  Future lookAt(Vector3 position, {Vector3? focus, Vector3? up}) async {
    focus ??= Vector3.zero();
    up ??= Vector3(0, 1, 0);
    final viewMatrix = makeViewMatrix(position, focus, up);
    viewMatrix.invert();
    await setModelMatrix(viewMatrix);
  }

  ///
  /// From Camera.h:
  ///
  /// Sets this camera's exposure (default is f/16, 1/125s, 100 ISO)
  ///
  /// The exposure ultimately controls the scene's brightness, just like with a real camera.
  /// The default values provide adequate exposure for a camera placed outdoors on a sunny day
  /// with the sun at the zenith.
  ///
  /// @param aperture      Aperture in f-stops, clamped between 0.5 and 64.
  ///                      A lower \p aperture value ///increases/// the exposure, leading to
  ///                      a brighter scene. Realistic values are between 0.95 and 32.
  ///
  /// @param shutterSpeed  Shutter speed in seconds, clamped between 1/25,000 and 60.
  ///                      A lower shutter speed increases the exposure. Realistic values are
  ///                      between 1/8000 and 30.
  ///
  /// @param sensitivity   Sensitivity in ISO, clamped between 10 and 204,800.
  ///                      A higher \p sensitivity increases the exposure. Realistic values are
  ///                      between 50 and 25600.
  ///
  /// @note
  /// With the default parameters, the scene must contain at least one Light of intensity
  /// similar to the sun (e.g.: a 100,000 lux directional light).
  Future setExposure(
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

  /// Get the entity that has the underlying Camera component attached.
  ///
  ///
  ThermionEntity getEntity();

  /// Set the transform for this entity.
  ///
  ///
  Future setTransform(Matrix4 transform);

  /// Gets the distance to the near plane.
  ///
  ///
  Future<double> getNear();
  
  /// Gets the distance to the far plane used for culling.
  ///
  ///
  Future<double> getCullingFar();
  
  ///
  ///
  ///
  Future<double> getFocalLength();
  
  /// Get the focus distance for depth-of-field postprocessing effect. 
  /// If DoF is not enabled, this does nothing.
  ///
  Future<double> getFocusDistance();
  
  /// Set the focus distance for depth-of-field postprocessing effect. 
  /// If DoF is not enabled, this does nothing.
  ///
  Future setFocusDistance(double focusDistance);
  
  Future<double> getHorizontalFieldOfView();
  Future<double> getVerticalFieldOfView();
  Future<Frustum> getFrustum();

  Future destroy();
}
