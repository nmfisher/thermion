/// Native platforms: no Emscripten WebGPU device export, so the feature is
/// reported as unavailable.

/// No browser `GPUDevice` exists on native platforms.
Object? exportWebGPUDevice() => null;
