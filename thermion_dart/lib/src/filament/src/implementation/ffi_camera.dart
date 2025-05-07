import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

import '../../../utils/src/matrix.dart';

class FFICamera extends Camera {
  final Pointer<TCamera> camera;
  final FFIFilamentApp app;
  late ThermionEntity _entity;

  FFICamera(this.camera, this.app) {
    _entity = Camera_getEntity(camera);
  }

  ///
  ///
  ///
  @override
  Future setProjectionMatrixWithCulling(
      Matrix4 projectionMatrix, double near, double far) async {
    Camera_setCustomProjectionWithCulling(
        camera, matrix4ToDouble4x4(projectionMatrix), near, far);
  }

  ///
  ///
  ///
  Future<Matrix4> getModelMatrix() async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }
    final modelMatrix = double4x4ToMatrix4(Camera_getModelMatrix(camera));
    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
    }
    return modelMatrix;
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getProjectionMatrix() async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }
    var matrixStruct = Camera_getProjectionMatrix(camera);
    final pMat = double4x4ToMatrix4(matrixStruct);
    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
    }
    return pMat;
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCullingProjectionMatrix() async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }
    var matrixStruct = Camera_getCullingProjectionMatrix(camera);
    final cpMat = double4x4ToMatrix4(matrixStruct);

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
    }
    return cpMat;
  }

  @override
  Future setTransform(Matrix4 transform) async {
    var entity = Camera_getEntity(camera);
    TransformManager_setTransform(
        app.transformManager, entity, matrix4ToDouble4x4(transform));
  }

  @override
  Future setLensProjection(
      {double near = kNear,
      double far = kFar,
      double aspect = 1.0,
      double focalLength = kFocalLength}) async {
    Camera_setLensProjection(camera, near, far, aspect, focalLength);
  }

  ///
  ///
  ///
  @override
  ThermionEntity getEntity() {
    return _entity;
  }

  ///
  ///
  ///
  @override
  Future setModelMatrix(Matrix4 matrix) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }
    Camera_setModelMatrix(camera, matrix.storage.address);
    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
      matrix.storage.free();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FFICamera &&
          runtimeType == other.runtimeType &&
          camera == other.camera;

  @override
  int get hashCode => camera.hashCode;

  ///
  ///
  ///
  @override
  Future<double> getCullingFar() async {
    return Camera_getCullingFar(camera);
  }

  ///
  ///
  ///
  @override
  Future<double> getNear() async {
    return Camera_getNear(camera);
  }

  ///
  ///
  ///
  @override
  Future<double> getFocalLength() async {
    return Camera_getFocalLength(camera);
  }

  ///
  ///
  ///
  Future<Frustum> getFrustum() async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }
    var out = Float64List(24);
    Camera_getFrustum(camera, out.address);

    var frustum = Frustum();
    frustum.plane0.setFromComponents(out[0], out[1], out[2], out[3]);
    frustum.plane1.setFromComponents(out[4], out[5], out[6], out[7]);
    frustum.plane2.setFromComponents(out[8], out[9], out[10], out[11]);
    frustum.plane3.setFromComponents(out[12], out[13], out[14], out[15]);
    frustum.plane4.setFromComponents(out[16], out[17], out[18], out[19]);
    frustum.plane5.setFromComponents(out[20], out[21], out[22], out[23]);
    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      out.free();
    }
    return frustum;
  }

  @override
  Future<Matrix4> getViewMatrix() async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }
    final matrix = double4x4ToMatrix4(Camera_getViewMatrix(camera));
    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
    }
    return matrix;
  }

  @override
  Future setProjection(Projection projection, double left, double right,
      double bottom, double top, double near, double far) async {
    Camera_setProjection(
        camera, projection.index, left, right, bottom, top, near, far);
  }

  Future destroy() async {
    Engine_destroyCamera(app.engine, camera);
  }

  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    Camera_setExposure(camera, aperture, shutterSpeed, sensitivity);
  }

  Future<double> getFocusDistance() async => Camera_getFocusDistance(camera);
  Future setFocusDistance(double focusDistance) async =>
      Camera_setFocusDistance(camera, focusDistance);

  @override
  Future<double> getHorizontalFieldOfView() async {
    return Camera_getFov(camera, true);
  }

  @override
  Future<double> getVerticalFieldOfView() async {
    return Camera_getFov(camera, false);
  }
}
