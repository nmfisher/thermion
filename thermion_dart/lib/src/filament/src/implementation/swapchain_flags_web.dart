/// Web js_interop bindings: `uint64_t` flags are `BigInt`.
library;

import '../../../bindings/src/js_interop.dart' as bindings;

/// Forwards the web flag word to the generated entry point.
void engineCreateSwapChainJobThread(
  bindings.Pointer<bindings.TJobThread> jobThread,
  bindings.Pointer<bindings.TEngine> engine,
  bindings.Pointer<bindings.Void> window,
  Object flags,
  bindings.Pointer<bindings.NativeFunction<void Function(bindings.Pointer<bindings.TSwapChain>)>> onComplete,
) {
  bindings.Engine_createSwapChainJobThread(jobThread, engine, window, flags as BigInt, onComplete);
}
