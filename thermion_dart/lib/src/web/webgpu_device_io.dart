/// Native platforms: no browser `GPUDevice` exists, so the export always
/// reports unavailable. Only the web variant calls into the engine.
library;

/// No browser `GPUDevice` exists on native platforms.
Object? exportWebGPUDeviceJsObject() => null;
