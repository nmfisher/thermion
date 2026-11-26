/// Native platforms: no Emscripten hidden canvas exists, so offscreen
/// (present-skip) swapchains are unavailable. The web variant is only
/// compiled under dart2js/dart2wasm.
library;

import 'package:thermion_dart/thermion_dart.dart';

import '../filament/src/implementation/ffi_filament_app.dart';

/// Present-skip swapchains need the web engine's hidden canvas.
bool get supportsSkipPresent => false;

/// Never reached (the extension guards on [supportsSkipPresent]).
String? offscreenCanvasSelector(String canvasSelector) => null;

/// Never reached (the extension guards on [supportsSkipPresent]).
Future<SwapChain> createOffscreenSwapChain(FFIFilamentApp app, int windowAddress, {bool hasStencilBuffer = false}) {
  throw UnsupportedError('Offscreen (present-skip) swapchains are only supported by the WebGPU backend in web builds.');
}
