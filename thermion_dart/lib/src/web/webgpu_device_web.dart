/// WebGPU device export, web implementation. Compiled only under
/// dart2js/dart2wasm (see webgpu_device.dart's conditional export).
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// The web bindings library (not bindings.dart, whose conditional export
// resolves to the native FFI variant when analyzed on a native host).
import '../bindings/src/js_interop.dart' as bindings;

/// Module property the engine publishes the exported `GPUDevice` on
/// (Thermion_exportWebGPUDevice in native/web/include/ThermionWebApi.h).
const String webGPUDeviceModuleProperty = 'thermionWebGPUDevice';

/// Asks the engine to hand the `GPUDevice` its WebGPU backend runs on to
/// JavaScript and returns the JS object, so a sidecar renderer can share
/// the device.
///
/// Null when there is no WebGPU device: a WebGL2 engine, or no engine
/// created with `Backend.WEBGPU` yet.
Object? exportWebGPUDeviceJsObject() {
  if (bindings.Thermion_exportWebGPUDevice() == 0) return null;
  final module = bindings.NativeLibrary.instance;
  return module.getProperty<JSObject?>(webGPUDeviceModuleProperty.toJS);
}
