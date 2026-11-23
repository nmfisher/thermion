/// WebGPU device interop with the Emscripten engine.
///
/// Web only: the native side exports the browser `GPUDevice` driving the
/// WebGPU backend to JavaScript (see `native/web/include/ThermionWebApi.h`).
/// Native platforms have no such export, so the io variant reports the
/// feature as unavailable.
export 'webgpu_interop_io.dart'
    if (dart.library.io) 'webgpu_interop_io.dart'
    if (dart.library.js_interop) 'webgpu_interop_web.dart';
