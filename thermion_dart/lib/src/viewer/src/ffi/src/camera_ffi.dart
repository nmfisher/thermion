import 'dart:ffi';

import 'package:vector_math/vector_math_64.dart';

import '../../../../utils/matrix.dart';
import '../../shared_types/camera.dart';
import '../../thermion_viewer_base.dart';
import 'thermion_dart.g.dart';

class ThermionFFICamera extends Camera {
  final Pointer<TCamera> camera;
  final Pointer<TEngine> engine;
  late ThermionEntity _entity;

  ThermionFFICamera(this.camera, this.engine) {
    _entity = Camera_getEntity(camera);
  }

  @override
  Future setProjectionMatrixWithCulling(
      Matrix4 projectionMatrix, double near, double far) async {
    Camera_setCustomProjectionWithCulling(
        camera, matrix4ToDouble4x4(projectionMatrix), near, far);
  }

  Future<Matrix4> getModelMatrix() async {
    return double4x4ToMatrix4(Camera_getModelMatrix(camera));
  }

  @override
  Future setTransform(Matrix4 transform) async {
    var entity = Camera_getEntity(camera);
    Engine_setTransform(engine, entity, matrix4ToDouble4x4(transform));
  }

  @override
  Future setLensProjection(
      {double near = kNear,
      double far = kFar,
      double aspect = 1.0,
      double focalLength = kFocalLength}) async {
    Camera_setLensProjection(camera, near, far, aspect, focalLength);
  }

  @override
  ThermionEntity getEntity() {
    return _entity;
  }

  @override
  Future setModelMatrix(Matrix4 matrix) async {
    Camera_setModelMatrix(camera, matrix4ToDouble4x4(matrix));
  }
}
