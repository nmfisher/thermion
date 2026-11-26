/// Native platforms: no Emscripten hidden canvas exists, so offscreen
/// swapchains are unavailable (only the WebGPU engine on web implements
/// them). The web variant is only compiled under dart2js/dart2wasm.
library;

/// Offscreen swapchains need the web engine's hidden canvas.
bool get supportsSkipPresent => false;

/// Never reached (the extension guards on [supportsSkipPresent]).
String? offscreenCanvasSelector(int jobThreadAddress) => null;

/// Never reached (the extension guards on [supportsSkipPresent]).
Future<int> createOffscreenSwapChain(int jobThreadAddress, int engineAddress, {bool hasStencilBuffer = false}) {
  throw UnsupportedError('Offscreen swapchains are only supported by the WebGPU engine in web builds.');
}
