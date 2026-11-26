/// The browser `GPUDevice` handle, platform-neutral.
///
/// `package:web` (1.x) only ships the WebGPU usage-flag constants, not the
/// object interfaces, so this opaque stand-in for `web.GPUDevice` exists on
/// every platform (the VM cannot compile `dart:js_interop`). On web it
/// wraps the very JS object the browser handed the engine
/// (`Module['preinitializedWebGPUDevice']`): unwrap it with [jsObject] and
/// pass it to other WebGPU code (e.g. a sidecar's `WebGPU.importJsDevice`),
/// or reach members via `dart:js_interop_unsafe`. On native it is never
/// instantiated.
library;

import 'webgpu_device.dart' as impl;

class GPUDevice {
  /// The underlying JS `GPUDevice` reference (`JSObject` on web).
  final Object jsObject;

  GPUDevice._(this.jsObject);
}

/// Asks the engine to export its WebGPU backend's browser `GPUDevice`.
/// Null on native, on non-WebGPU engines, and before engine creation.
GPUDevice? exportWebGPUDevice() {
  final jsObject = impl.exportWebGPUDeviceJsObject();
  return jsObject == null ? null : GPUDevice._(jsObject);
}
