import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// The web bindings library (not bindings.dart, whose conditional export
// resolves to the native FFI variant when analyzed on a native host).
import '../../../bindings/src/js_interop.dart' as bindings;

/// Module property the engine publishes the exported `GPUDevice` on
/// (Thermion_exportWebGPUDevice in native/web/include/ThermionWebApi.h).
const String webGPUDeviceModuleProperty = 'thermionWebGPUDevice';

/// Present-skip swapchains are rendered into the engine's hidden canvas.
bool get supportsSkipPresent => true;

/// `THERMION_SWAP_CHAIN_CONFIG_SKIP_PRESENT` from the engine, as the shared
/// `int` swapchain-flag type (the bit fits a Dart int: 1 << 62).
int get skipPresentFlag => bindings.TSWAP_CHAIN_CONFIG_SKIP_PRESENT.toInt();

/// Asks the engine to hand the `GPUDevice` its WebGPU backend runs on to
/// JavaScript and returns it, so a sidecar renderer can share the device.
///
/// Null when there is no WebGPU device: a WebGL2 engine, or no engine created
/// with `Backend.WEBGPU` yet.
JSObject? exportWebGPUDevice() {
  if (bindings.Thermion_exportWebGPUDevice() == 0) return null;
  final module = bindings.NativeLibrary.instance;
  return module.getProperty<JSObject?>(webGPUDeviceModuleProperty.toJS);
}

/// Selector ("#id") of the hidden canvas that receives the offscreen
/// (present-skip) swapchain frames of the canvas [canvasSelector], creating
/// the canvas on first use. Null when the page has no document body.
String? offscreenCanvasSelector(String canvasSelector) {
  // toNativeUtf8 stack-allocates; the engine copies the selector before
  // returning, so no heap free is needed (matches FFIFilamentApp.create).
  final selectorPtr = canvasSelector.toNativeUtf8();
  final result = bindings.Thermion_getOffscreenCanvasSelector(selectorPtr);
  if (result.address == 0) return null;
  return result.toDartString();
}
