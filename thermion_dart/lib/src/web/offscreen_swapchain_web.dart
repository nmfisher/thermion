/// Offscreen (present-skip) swapchain plumbing, web implementation.
/// Compiled only under dart2js/dart2wasm (see offscreen_swapchain.dart's
/// conditional export).
library;

// The web bindings library (not bindings.dart, whose conditional export
// resolves to the native FFI variant when analyzed on a native host).
import '../bindings/src/js_interop.dart' as bindings;
import '../filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Present-skip swapchains are rendered into the engine's hidden canvas.
bool get supportsSkipPresent => true;

/// Selector ("#id") of the hidden canvas that receives the offscreen
/// (present-skip) swapchain frames of the canvas [canvasSelector], creating
/// the canvas on first use. Null when the page has no document body.
String? offscreenCanvasSelector(String canvasSelector) {
  // toNativeUtf8 stack-allocates on the Wasm stack; JS callers never unwind
  // it, so save/restore around the call or every invocation leaks stack.
  final stack = bindings.stackSave();
  try {
    final selectorPtr = bindings.StringUtils(canvasSelector).toNativeUtf8();
    final result = bindings.Thermion_getOffscreenCanvasSelector(selectorPtr);
    if (result.address == 0) return null;
    return bindings.CharPtr(result).toDartString();
  } finally {
    bindings.stackRestore(stack);
  }
}

/// Creates a swapchain with `THERMION_SWAP_CHAIN_CONFIG_SKIP_PRESENT` set:
/// the WebGPU engine renders every frame into the hidden canvas (see
/// [offscreenCanvasSelector]) and never presents it.
///
/// The flag word is BigInt in the web bindings (`uint64_t`), so it is built
/// here rather than OR-ed into the native `int` word.
Future<SwapChain> createOffscreenSwapChain(FFIFilamentApp app, int windowAddress, {bool hasStencilBuffer = false}) {
  var flags = bindings.TSWAP_CHAIN_CONFIG_TRANSPARENT | bindings.TSWAP_CHAIN_CONFIG_READABLE;
  if (hasStencilBuffer) {
    flags |= bindings.TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;
  }
  flags |= bindings.TSWAP_CHAIN_CONFIG_SKIP_PRESENT;
  // The engine presents to its own canvas; the window address only carries
  // a native handle, 0 on web exactly like createSwapChain(nullptr).
  return app.createSwapChainFromFlags(windowAddress, flags);
}
