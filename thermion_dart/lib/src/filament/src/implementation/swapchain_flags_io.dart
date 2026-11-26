/// Native ffi bindings: `uint64_t` flags are plain `int`.
library;

import 'dart:ffi' as ffi;

import '../../../bindings/src/ffi.dart' as bindings;

/// Forwards the native flag word to the generated entry point.
void engineCreateSwapChainJobThread(
  bindings.Pointer<bindings.TJobThread> jobThread,
  bindings.Pointer<bindings.TEngine> engine,
  bindings.Pointer<ffi.Void> window,
  Object flags,
  bindings.Pointer<ffi.NativeFunction<ffi.Void Function(bindings.Pointer<bindings.TSwapChain>)>> onComplete,
) {
  bindings.Engine_createSwapChainJobThread(jobThread, engine, window, flags as int, onComplete);
}
