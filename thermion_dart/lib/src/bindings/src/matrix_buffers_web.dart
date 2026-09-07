import 'js_interop.dart';

// A scoped WASM buffer avoids per-element JS interop and restores the stack
// synchronously, including for queue submissions. Native queue entry points
// snapshot the input before returning; no stack address survives an await.
void _withMatrix(Float64List data, void Function(Pointer<Float64>) call, {bool output = false}) {
  if (data.length != 16) throw ArgumentError.value(data.length, 'matrix length', 'Expected 16 doubles');
  final marker = stackSave();
  try {
    final pointer = stackAlloc<Float64>(128);
    final storage = (Float64ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, pointer, 16) as JSFloat64Array).toDart;
    if (!output) storage.setRange(0, 16, data);
    call(pointer);
    if (output) data.setRange(0, 16, storage);
  } finally {
    stackRestore(marker);
  }
}

void readLocalTransform(Pointer<TTransformManager> manager, int entity, Float64List out) =>
    _withMatrix(out, (ptr) => TransformManager_getLocalTransformInto(manager, entity, ptr), output: true);
void readWorldTransform(Pointer<TTransformManager> manager, int entity, Float64List out) =>
    _withMatrix(out, (ptr) => TransformManager_getWorldTransformInto(manager, entity, ptr), output: true);
void writeTransform(Pointer<TTransformManager> manager, int entity, Float64List matrix) =>
    _withMatrix(matrix, (ptr) => TransformManager_setTransformFromBuffer(manager, entity, ptr));
void queueTransform(
  Pointer<TTransformManager> manager,
  int entity,
  Float64List matrix,
  int requestId,
  VoidCallback callback,
) => _withMatrix(
  matrix,
  (ptr) => TransformManager_setTransformFromBufferRenderThread(manager, entity, ptr, requestId, callback),
);
void writeCameraModel(Pointer<TCamera> camera, Float64List matrix) =>
    _withMatrix(matrix, (ptr) => Camera_setModelMatrixFromBuffer(camera, ptr));
void writeCameraProjection(Pointer<TCamera> camera, Float64List matrix, double near, double far) =>
    _withMatrix(matrix, (ptr) => Camera_setCustomProjectionWithCullingFromBuffer(camera, ptr, near, far));
void readCameraModel(Pointer<TCamera> camera, Float64List out) =>
    _withMatrix(out, (ptr) => Camera_getModelMatrixInto(camera, ptr), output: true);
void readCameraView(Pointer<TCamera> camera, Float64List out) =>
    _withMatrix(out, (ptr) => Camera_getViewMatrixInto(camera, ptr), output: true);
void readCameraProjection(Pointer<TCamera> camera, Float64List out) =>
    _withMatrix(out, (ptr) => Camera_getProjectionMatrixInto(camera, ptr), output: true);
void readCameraCullingProjection(Pointer<TCamera> camera, Float64List out) =>
    _withMatrix(out, (ptr) => Camera_getCullingProjectionMatrixInto(camera, ptr), output: true);
