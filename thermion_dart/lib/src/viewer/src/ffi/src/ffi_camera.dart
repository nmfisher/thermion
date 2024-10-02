import 'dart:ffi';

import 'package:vector_math/vector_math_64.dart';

import '../../../../utils/matrix.dart';
import '../../thermion_viewer_base.dart';
import 'thermion_dart.g.dart' as g;

class FFICamera extends Camera {
  final Pointer<g.TCamera> camera;
  final Pointer<g.TEngine> engine;
  late ThermionEntity _entity;

  FFICamera(this.camera, this.engine) {
    _entity = g.Camera_getEntity(camera);
  }

  @override
  Future setProjectionMatrixWithCulling(
      Matrix4 projectionMatrix, double near, double far) async {
    g.Camera_setCustomProjectionWithCulling(
        camera, matrix4ToDouble4x4(projectionMatrix), near, far);
  }

  Future<Matrix4> getModelMatrix() async {
    return double4x4ToMatrix4(g.Camera_getModelMatrix(camera));
  }

  @override
  Future setTransform(Matrix4 transform) async {
    var entity = g.Camera_getEntity(camera);
    g.Engine_setTransform(engine, entity, matrix4ToDouble4x4(transform));
  }

  @override
  Future setLensProjection(
      {double near = kNear,
      double far = kFar,
      double aspect = 1.0,
      double focalLength = kFocalLength}) async {
    g.Camera_setLensProjection(camera, near, far, aspect, focalLength);
  }

  @override
  ThermionEntity getEntity() {
    return _entity;
  }

  @override
  Future setModelMatrix(Matrix4 matrix) async {
    g.Camera_setModelMatrix(camera, matrix4ToDouble4x4(matrix));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FFICamera &&
          runtimeType == other.runtimeType &&
          camera == other.camera;

  @override
  int get hashCode => camera.hashCode;

  @override
  Future<double> getCullingFar() async {
    return g.Camera_getCullingFar(camera);
  }

  @override
  Future<double> getNear() async {
    return g.Camera_getNear(camera);
  }

  @override
  Future<double> getFocalLength() async {
    return g.Camera_getFocalLength(camera);
  }

  @override
  Future<Matrix4> getViewMatrix() async {
    return double4x4ToMatrix4(g.Camera_getViewMatrix(camera));
  }

  @override
  Future setProjection(Projection projection, double left, double right,
      double bottom, double top, double near, double far) async  {
    var pType = g.Projection.values[projection.index];
    g.Camera_setProjection(camera, pType, left,
        right, bottom, top, near, far);
  }
}
