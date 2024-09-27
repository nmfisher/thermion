import 'package:vector_math/vector_math_64.dart';

import '../thermion_viewer_base.dart';

abstract class Camera {
  Future setProjectionMatrixWithCulling(
      Matrix4 projectionMatrix, double near, double far);

  Future setLensProjection(
      {double near = kNear,
      double far = kFar,
      double aspect = 1.0,
      double focalLength = kFocalLength});

  Future<Matrix4> getViewMatrix();
  Future<Matrix4> getModelMatrix();
  Future setModelMatrix(Matrix4 matrix);

  ThermionEntity getEntity();

  Future setTransform(Matrix4 transform);

  Future<double> getNear();
  Future<double> getCullingFar();
  Future<double> getFocalLength();
}