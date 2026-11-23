/// Native platforms: no Emscripten WebGPU device export and no hidden
/// canvas, so both features are reported as unavailable.

/// Present-skip swapchains need the web engine's hidden canvas.
bool get supportsSkipPresent => false;

/// Never used (see [supportsSkipPresent]); zero in the native `int`
/// swapchain-flag type. The web variant returns the web bindings' `BigInt`
/// flag instead; the two variants are never compiled together.
int get skipPresentFlag => 0;

/// No browser `GPUDevice` exists on native platforms.
Object? exportWebGPUDevice() => null;

/// No hidden canvas exists on native platforms.
String? offscreenCanvasSelector(String canvasSelector) => null;
