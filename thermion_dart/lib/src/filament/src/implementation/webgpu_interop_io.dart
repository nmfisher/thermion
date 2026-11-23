/// Native platforms: no Emscripten WebGPU device export and no hidden
/// canvas, so both features are reported as unavailable.

/// Present-skip swapchains need the web engine's hidden canvas.
bool get supportsSkipPresent => false;

/// Never used (see [supportsSkipPresent]); keeps the shared flag arithmetic
/// typed like the native `int` swapchain flags.
int get skipPresentFlag => 0;

/// No browser `GPUDevice` exists on native platforms.
Object? exportWebGPUDevice() => null;

/// No hidden canvas exists on native platforms.
String? offscreenCanvasSelector(String canvasSelector) => null;
