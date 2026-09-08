import 'dart:ffi' as ffi;
import 'dart:typed_data' as typed_data;
import 'thermion_dart_ffi.g.dart';

// Ordinary Dart adapters borrow typed-data storage for generated leaf calls.
// Native declarations and their signatures remain entirely owned by ffigen.

/// Borrows 16 column-major doubles for the duration of the leaf call.
void Camera_getCullingProjectionMatrixIntoTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List out16) {
  assert(out16.length == 16, 'Expected 16 doubles');
  Camera_getCullingProjectionMatrixInto(camera, out16.address);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void Camera_getModelMatrixIntoTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List out16) {
  assert(out16.length == 16, 'Expected 16 doubles');
  Camera_getModelMatrixInto(camera, out16.address);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void Camera_getProjectionMatrixIntoTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List out16) {
  assert(out16.length == 16, 'Expected 16 doubles');
  Camera_getProjectionMatrixInto(camera, out16.address);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void Camera_getViewMatrixIntoTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List out16) {
  assert(out16.length == 16, 'Expected 16 doubles');
  Camera_getViewMatrixInto(camera, out16.address);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void Camera_setCustomProjectionWithCullingFromBufferTypedData(
  ffi.Pointer<TCamera> camera,
  typed_data.Float64List matrix16,
  double near,
  double far,
) {
  assert(matrix16.length == 16, 'Expected 16 doubles');
  Camera_setCustomProjectionWithCullingFromBuffer(camera, matrix16.address, near, far);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void Camera_setModelMatrixFromBufferTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List matrix16) {
  assert(matrix16.length == 16, 'Expected 16 doubles');
  Camera_setModelMatrixFromBuffer(camera, matrix16.address);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void TransformManager_getLocalTransformIntoTypedData(
  ffi.Pointer<TTransformManager> manager,
  int entity,
  typed_data.Float64List out16,
) {
  assert(out16.length == 16, 'Expected 16 doubles');
  TransformManager_getLocalTransformInto(manager, entity, out16.address);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void TransformManager_getWorldTransformIntoTypedData(
  ffi.Pointer<TTransformManager> manager,
  int entity,
  typed_data.Float64List out16,
) {
  assert(out16.length == 16, 'Expected 16 doubles');
  TransformManager_getWorldTransformInto(manager, entity, out16.address);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void TransformManager_setTransformFromBufferTypedData(
  ffi.Pointer<TTransformManager> manager,
  int entity,
  typed_data.Float64List matrix16,
) {
  assert(matrix16.length == 16, 'Expected 16 doubles');
  TransformManager_setTransformFromBuffer(manager, entity, matrix16.address);
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void TransformManager_setTransformFromBufferRenderThreadTypedData(
  ffi.Pointer<TTransformManager> manager,
  int entity,
  typed_data.Float64List matrix16,
  int requestId,
  VoidCallback onComplete,
) {
  assert(matrix16.length == 16, 'Expected 16 doubles');
  TransformManager_setTransformFromBufferRenderThread(manager, entity, matrix16.address, requestId, onComplete);
}
