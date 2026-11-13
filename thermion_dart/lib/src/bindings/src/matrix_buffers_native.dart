import 'dart:ffi' as ffi;
import 'dart:typed_data' as typed_data;
import 'thermion_dart_ffi.g.dart';
import 'heap_buffer_ffi.dart';

typed_data.Float64List nativeMatrixStorage(ffi.Pointer<TMat4> owner) => Mat4_getData(owner).asTypedList(16);

// Guarded exports may block, so pass stable native storage across FFI.
// Native declarations and their signatures remain entirely owned by ffigen.
// Reuse one per-isolate 16-double scratch buffer on the non-reentrant hot path.
final _matrixScratch = NativeScratchBuffer<ffi.Double>(16 * ffi.sizeOf<ffi.Double>());
bool _matrixScratchInUse = false;

void _withMatrixInput(typed_data.Float64List matrix16, void Function(ffi.Pointer<ffi.Double>) operation) {
  assert(matrix16.length == 16, 'Expected 16 doubles');
  if (_matrixScratchInUse) {
    withNativeBuffer(matrix16, (ptr) => operation(ptr.cast()));
    return;
  }
  _matrixScratchInUse = true;
  try {
    _matrixScratch.pointer.asTypedList(16).setAll(0, matrix16);
    operation(_matrixScratch.pointer);
  } finally {
    _matrixScratchInUse = false;
  }
}

void _withMatrixOutput(typed_data.Float64List out16, void Function(ffi.Pointer<ffi.Double>) operation) {
  assert(out16.length == 16, 'Expected 16 doubles');
  if (_matrixScratchInUse) {
    withNativeBuffer(out16, (ptr) => operation(ptr.cast()), copyIn: false, copyBack: true);
    return;
  }
  _matrixScratchInUse = true;
  try {
    operation(_matrixScratch.pointer);
    out16.setAll(0, _matrixScratch.pointer.asTypedList(16));
  } finally {
    _matrixScratchInUse = false;
  }
}

/// Copies 16 column-major doubles through stable native storage.
void Camera_getCullingProjectionMatrixIntoTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List out16) {
  _withMatrixOutput(out16, (ptr) => Camera_getCullingProjectionMatrixInto(camera, ptr));
}

/// Copies 16 column-major doubles through stable native storage.
void Camera_getModelMatrixIntoTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List out16) {
  _withMatrixOutput(out16, (ptr) => Camera_getModelMatrixInto(camera, ptr));
}

/// Copies 16 column-major doubles through stable native storage.
void Camera_getProjectionMatrixIntoTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List out16) {
  _withMatrixOutput(out16, (ptr) => Camera_getProjectionMatrixInto(camera, ptr));
}

/// Copies 16 column-major doubles through stable native storage.
void Camera_getViewMatrixIntoTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List out16) {
  _withMatrixOutput(out16, (ptr) => Camera_getViewMatrixInto(camera, ptr));
}

/// Copies 16 column-major doubles through stable native storage.
void Camera_setCustomProjectionWithCullingFromBufferTypedData(
  ffi.Pointer<TCamera> camera,
  typed_data.Float64List matrix16,
  double near,
  double far,
) {
  _withMatrixInput(matrix16, (ptr) => Camera_setCustomProjectionWithCullingFromBuffer(camera, ptr, near, far));
}

/// Copies 16 column-major doubles through stable native storage.
void Camera_setModelMatrixFromBufferTypedData(ffi.Pointer<TCamera> camera, typed_data.Float64List matrix16) {
  _withMatrixInput(matrix16, (ptr) => Camera_setModelMatrixFromBuffer(camera, ptr));
}

/// Copies 16 column-major doubles through stable native storage.
void TransformManager_getLocalTransformIntoTypedData(
  ffi.Pointer<TTransformManager> manager,
  int entity,
  typed_data.Float64List out16,
) {
  _withMatrixOutput(out16, (ptr) => TransformManager_getLocalTransformInto(manager, entity, ptr));
}

/// Copies 16 column-major doubles through stable native storage.
void TransformManager_getWorldTransformIntoTypedData(
  ffi.Pointer<TTransformManager> manager,
  int entity,
  typed_data.Float64List out16,
) {
  _withMatrixOutput(out16, (ptr) => TransformManager_getWorldTransformInto(manager, entity, ptr));
}

/// Copies 16 column-major doubles through stable native storage.
void TransformManager_setTransformFromBufferTypedData(
  ffi.Pointer<TTransformManager> manager,
  int entity,
  typed_data.Float64List matrix16,
) {
  _withMatrixInput(matrix16, (ptr) => TransformManager_setTransformFromBuffer(manager, entity, ptr));
}

/// Borrows 16 column-major doubles for the duration of the leaf call.
void TransformManager_setTransformFromBufferJobThreadTypedData(
  ffi.Pointer<TJobThread> jobThread,
  ffi.Pointer<TTransformManager> manager,
  int entity,
  typed_data.Float64List matrix16,
  int requestId,
  VoidCallback onComplete,
) {
  assert(matrix16.length == 16, 'Expected 16 doubles');
  TransformManager_setTransformFromBufferJobThread(jobThread, manager, entity, matrix16.address, requestId, onComplete);
}
