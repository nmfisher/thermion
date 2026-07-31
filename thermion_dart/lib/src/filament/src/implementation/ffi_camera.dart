import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

import '../../../utils/src/matrix.dart';

class FFICamera extends Camera<Pointer<TCamera>> {
  final Pointer<TCamera> camera;

  @override
  Pointer<TCamera> getNativeHandle() {
    return camera;
  }

  late ThermionEntity _entity;

  final FFIFilamentApp _app;

  FFICamera(this.camera, this._app) {
    _entity = Camera_getEntity(camera);
  }

  ///
  @override
  Future setProjectionMatrixWithCulling(
    Matrix4 projectionMatrix,
    double near,
    double far,
  ) async {
    Camera_setCustomProjectionWithCulling(
      camera,
      matrix4ToDouble4x4(projectionMatrix),
      near,
      far,
    );
  }

  //
  @override
  Future setProjectionFromHorizontalFieldOfView(
    double degrees,
    double near,
    double far,
    double aspect,
  ) async {
    if (degrees.isNaN) {
      throw FormatException('fov must not be NaN, but was $degrees.');
    }
    if (degrees <= 0) {
      throw FormatException('fov must be positive, but was $degrees.');
    }
    if (degrees >= 180) {
      throw FormatException(
        'fov must be less than 180 degrees, but was $degrees.',
      );
    }
    if (near.isNaN) {
      throw FormatException('near must not be NaN, but was $near.');
    }
    if (far.isNaN) {
      throw FormatException('far must not be NaN, but was $far.');
    }
    if (near.isNegative || near == 0) {
      throw FormatException('near must be positive, but was $near.');
    }
    if (far.isNegative || far == 0) {
      throw FormatException('far must be positive, but was $far.');
    }
    if (aspect.isNaN) {
      throw FormatException('aspect must not be NaN, but was $aspect.');
    }
    if (aspect.isNegative || aspect == 0) {
      throw FormatException('aspect must be positive, but was $aspect.');
    }
    Camera_setProjectionFromFov(camera, degrees, aspect, near, far, true);
  }

  //
  @override
  Future setProjectionFromVerticalFieldOfView(
    double degrees,
    double near,
    double far,
    double aspect,
  ) async {
    if (degrees.isNaN) {
      throw FormatException('fov must not be NaN, but was $degrees.');
    }
    if (degrees <= 0) {
      throw FormatException('fov must be positive, but was $degrees.');
    }
    if (degrees >= 180) {
      throw FormatException(
        'fov must be less than 180 degrees, but was $degrees.',
      );
    }
    if (near.isNaN) {
      throw FormatException('near must not be NaN, but was $near.');
    }
    if (far.isNaN) {
      throw FormatException('far must not be NaN, but was $far.');
    }
    if (near.isNegative || near == 0) {
      throw FormatException('near must be positive, but was $near.');
    }
    if (far.isNegative || far == 0) {
      throw FormatException('far must be positive, but was $far.');
    }
    if (aspect.isNaN) {
      throw FormatException('aspect must not be NaN, but was $aspect.');
    }
    if (aspect.isNegative || aspect == 0) {
      throw FormatException('aspect must be positive, but was $aspect.');
    }
    Camera_setProjectionFromFov(camera, degrees, aspect, near, far, false);
  }

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
    _app.transformManager.setTransform(entity, transform);
  }

  @override
  Future<void> setLensProjection({
    double near = kNear,
    double far = kFar,
    double aspect = 1.0,
    double focalLength = kFocalLength,
  }) async {
    if (near.isNaN) {
      throw FormatException('near must not be NaN, but was $near.');
    }
    if (far.isNaN) {
      throw FormatException('far must not be NaN, but was $far.');
    }
    if (aspect.isNaN) {
      throw FormatException('aspect must not be NaN, but was $aspect.');
    }
    if (focalLength.isNaN) {
      throw FormatException(
        'focalLength must not be NaN, but was $focalLength.',
      );
    }
    if (near.isNegative) {
      throw FormatException('near must not be negative, but was $near.');
    }
    if (far.isNegative) {
      throw FormatException('far must not be negative, but was $far.');
    }
    if (aspect.isNegative) {
      throw FormatException('aspect must not be negative, but was $aspect.');
    }
    if (focalLength.isNegative) {
      throw FormatException(
        'focalLength must not be negative, but was $focalLength.',
      );
    }

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

    // Filament returns the frustum in world space
    // Transform planes to camera space using (V^-1)^T = modelMatrix^T
    final transformMatrix = await getViewMatrix();
    transformMatrix.invert();

    // Transform each plane from world space to camera space
    for (int i = 0; i < 6; i++) {
      int idx = i * 4;

      // Extract plane as Vector4 (nx, ny, nz, d)
      var planeWorld = Vector4(
        out[idx],
        out[idx + 1],
        out[idx + 2],
        out[idx + 3],
      );

      // Transform plane to camera space: plane_camera = (V^-1)^T * plane_world
      var planeCamera = transformMatrix.transform(planeWorld);

      // Normalize the plane
      var normalLength = Vector3(
        planeCamera.x,
        planeCamera.y,
        planeCamera.z,
      ).length;
      if (normalLength > 0) {
        planeCamera = planeCamera / normalLength;
      }

      // Set the transformed plane
      switch (i) {
        case 0:
          frustum.plane0.setFromComponents(
            planeCamera.x,
            planeCamera.y,
            planeCamera.z,
            planeCamera.w,
          );
          break;
        case 1:
          frustum.plane1.setFromComponents(
            planeCamera.x,
            planeCamera.y,
            planeCamera.z,
            planeCamera.w,
          );
          break;
        case 2:
          frustum.plane2.setFromComponents(
            planeCamera.x,
            planeCamera.y,
            planeCamera.z,
            planeCamera.w,
          );
          break;
        case 3:
          frustum.plane3.setFromComponents(
            planeCamera.x,
            planeCamera.y,
            planeCamera.z,
            planeCamera.w,
          );
          break;
        case 4:
          frustum.plane4.setFromComponents(
            planeCamera.x,
            planeCamera.y,
            planeCamera.z,
            planeCamera.w,
          );
          break;
        case 5:
          frustum.plane5.setFromComponents(
            planeCamera.x,
            planeCamera.y,
            planeCamera.z,
            planeCamera.w,
          );
          break;
      }
    }

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
  Future setProjection(
    Projection projection,
    double left,
    double right,
    double bottom,
    double top,
    double near,
    double far,
  ) async {
    Camera_setProjection(
      camera,
      projection.index,
      left,
      right,
      bottom,
      top,
      near,
      far,
    );
  }

  Future destroy() async {
    await withVoidCallback(
      (requestId, cb) => Engine_destroyCameraRenderThread(
        _app.engine,
        camera,
        requestId,
        cb,
      ),
    );
  }

  Future setExposure(
    double aperture,
    double shutterSpeed,
    double sensitivity,
  ) async {
    Camera_setExposure(camera, aperture, shutterSpeed, sensitivity);
  }

  @override
  Future<double> getAperture() async => Camera_getAperture(camera);

  @override
  Future<double> getShutterSpeed() async => Camera_getShutterSpeed(camera);

  @override
  Future<double> getSensitivity() async => Camera_getSensitivity(camera);

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
