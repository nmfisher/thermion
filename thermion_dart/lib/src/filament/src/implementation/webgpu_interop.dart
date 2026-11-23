/// WebGPU device / offscreen-swapchain interop with the Emscripten engine.
///
/// Web only: the native side exports the browser `GPUDevice` driving the
/// WebGPU backend to JavaScript and hosts a hidden canvas for present-skip
/// swapchains (see `native/web/include/ThermionWebApi.h`). Native platforms
/// have neither, so the io variant reports the features as unavailable.
export 'webgpu_interop_io.dart'
    if (dart.library.io) 'webgpu_interop_io.dart'
    if (dart.library.js_interop) 'webgpu_interop_web.dart';
