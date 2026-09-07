import 'dart:ffi';
import 'dart:typed_data';
import 'thermion_dart_ffi.g.dart';

// Keep the leaf declarations and .address call sites in this library. Calling
// imported declarations with .address can leave their synthetic #PT trampoline
// missing when package:test loads kernels. The pointers below are borrowed only
// for the leaf call; queued setters copy their input before that call returns.
const _asset = 'package:thermion_dart/thermion_dart.dart';

@Native<Void Function(Pointer<TTransformManager>, Int32, Pointer<Double>)>(
  symbol: 'TransformManager_getLocalTransformInto',
  assetId: _asset,
  isLeaf: true,
)
external void _getLocal(Pointer<TTransformManager> manager, int entity, Pointer<Double> out);
@Native<Void Function(Pointer<TTransformManager>, Int32, Pointer<Double>)>(
  symbol: 'TransformManager_getWorldTransformInto',
  assetId: _asset,
  isLeaf: true,
)
external void _getWorld(Pointer<TTransformManager> manager, int entity, Pointer<Double> out);
@Native<Void Function(Pointer<TTransformManager>, Int32, Pointer<Double>)>(
  symbol: 'TransformManager_setTransformFromBuffer',
  assetId: _asset,
  isLeaf: true,
)
external void _setTransform(Pointer<TTransformManager> manager, int entity, Pointer<Double> matrix);
@Native<Void Function(Pointer<TTransformManager>, Int32, Pointer<Double>, Uint32, VoidCallback)>(
  symbol: 'TransformManager_setTransformFromBufferRenderThread',
  assetId: _asset,
  isLeaf: true,
)
external void _queueTransform(
  Pointer<TTransformManager> manager,
  int entity,
  Pointer<Double> matrix,
  int requestId,
  VoidCallback callback,
);

@Native<Void Function(Pointer<TCamera>, Pointer<Double>)>(
  symbol: 'Camera_setModelMatrixFromBuffer',
  assetId: _asset,
  isLeaf: true,
)
external void _setCameraModel(Pointer<TCamera> camera, Pointer<Double> matrix);
@Native<Void Function(Pointer<TCamera>, Pointer<Double>, Double, Double)>(
  symbol: 'Camera_setCustomProjectionWithCullingFromBuffer',
  assetId: _asset,
  isLeaf: true,
)
external void _setCameraProjection(Pointer<TCamera> camera, Pointer<Double> matrix, double near, double far);
@Native<Void Function(Pointer<TCamera>, Pointer<Double>)>(
  symbol: 'Camera_getModelMatrixInto',
  assetId: _asset,
  isLeaf: true,
)
external void _getCameraModel(Pointer<TCamera> camera, Pointer<Double> out);
@Native<Void Function(Pointer<TCamera>, Pointer<Double>)>(
  symbol: 'Camera_getViewMatrixInto',
  assetId: _asset,
  isLeaf: true,
)
external void _getCameraView(Pointer<TCamera> camera, Pointer<Double> out);
@Native<Void Function(Pointer<TCamera>, Pointer<Double>)>(
  symbol: 'Camera_getProjectionMatrixInto',
  assetId: _asset,
  isLeaf: true,
)
external void _getCameraProjection(Pointer<TCamera> camera, Pointer<Double> out);
@Native<Void Function(Pointer<TCamera>, Pointer<Double>)>(
  symbol: 'Camera_getCullingProjectionMatrixInto',
  assetId: _asset,
  isLeaf: true,
)
external void _getCameraCullingProjection(Pointer<TCamera> camera, Pointer<Double> out);

void _check(Float64List data) {
  if (data.length != 16) throw ArgumentError.value(data.length, 'matrix length', 'Expected 16 doubles');
}

void readLocalTransform(Pointer<TTransformManager> manager, int entity, Float64List out) {
  _check(out);
  _getLocal(manager, entity, out.address);
}

void readWorldTransform(Pointer<TTransformManager> manager, int entity, Float64List out) {
  _check(out);
  _getWorld(manager, entity, out.address);
}

void writeTransform(Pointer<TTransformManager> manager, int entity, Float64List matrix) {
  _check(matrix);
  _setTransform(manager, entity, matrix.address);
}

void queueTransform(
  Pointer<TTransformManager> manager,
  int entity,
  Float64List matrix,
  int requestId,
  VoidCallback callback,
) {
  _check(matrix);
  _queueTransform(manager, entity, matrix.address, requestId, callback);
}

void writeCameraModel(Pointer<TCamera> camera, Float64List matrix) {
  _check(matrix);
  _setCameraModel(camera, matrix.address);
}

void writeCameraProjection(Pointer<TCamera> camera, Float64List matrix, double near, double far) {
  _check(matrix);
  _setCameraProjection(camera, matrix.address, near, far);
}

void readCameraModel(Pointer<TCamera> camera, Float64List out) {
  _check(out);
  _getCameraModel(camera, out.address);
}

void readCameraView(Pointer<TCamera> camera, Float64List out) {
  _check(out);
  _getCameraView(camera, out.address);
}

void readCameraProjection(Pointer<TCamera> camera, Float64List out) {
  _check(out);
  _getCameraProjection(camera, out.address);
}

void readCameraCullingProjection(Pointer<TCamera> camera, Float64List out) {
  _check(out);
  _getCameraCullingProjection(camera, out.address);
}
