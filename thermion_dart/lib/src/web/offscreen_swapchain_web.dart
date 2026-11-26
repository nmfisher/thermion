/// Offscreen swapchain plumbing, web implementation.
/// Compiled only under dart2js/dart2wasm (see offscreen_swapchain.dart's
/// conditional export).
library;

import 'dart:js_interop_unsafe';

import '../bindings/src/js_interop.dart' as bindings;

/// JS name of the engine's offscreen entry point
/// (Thermion_createOffscreenSwapChain in native/web/include/ThermionWebApi.h).
const String _createOffscreenSwapChainExport = '_Thermion_createOffscreenSwapChain';

/// Only the WebGPU engine implements offscreen swapchains: the offscreen
/// entry point is compiled into WebGPU engines alone
/// (`-DTHERMION_ENABLE_WEBGPU=ON`) and only that backend can render into the
/// hidden canvas. Probing the loaded module for the export makes this reflect
/// the engine actually running, not just the web platform: a WebGL2 engine
/// reports the feature unavailable exactly like a native build.
bool get supportsSkipPresent => bindings.NativeLibrary.instance.has(_createOffscreenSwapChainExport);

/// Selector ("#id") of the hidden canvas that receives the offscreen
/// swapchain frames of the engine owning the job thread at
/// [jobThreadAddress], creating the canvas on first use. The engine resolves
/// its viewer canvas from the job thread's stored selector, so this always
/// matches what [createOffscreenSwapChain] renders into — also in
/// multi-viewer apps. Null when the page has no document body.
String? offscreenCanvasSelector(int jobThreadAddress) {
  final result = bindings.Thermion_getOffscreenCanvasSelector(bindings.Pointer<bindings.TJobThread>(jobThreadAddress));
  if (result.address == 0) return null;
  return bindings.CharPtr(result).toDartString();
}

/// Creates an offscreen swapchain on the engine at [engineAddress], owned by
/// the job thread at [jobThreadAddress], through the engine's web-only
/// `Thermion_createOffscreenSwapChain` export: the WebGPU engine renders
/// every frame into the hidden canvas (see [offscreenCanvasSelector]) and
/// never presents it. Returns the raw swapchain address (`Pointer.address`)
/// for the caller to adopt.
///
/// Offscreen-ness is carried by the entry point, never by a flag bit:
/// the flags handed to the engine are a pure OR of `TSWAP_CHAIN_CONFIG_*`
/// values, the bindings' 1:1 mirror of Filament's `SWAP_CHAIN_CONFIG_*`
/// (BigInt in the web bindings, `uint64_t`).
///
/// Throws when the page has no document body to host the hidden canvas
/// (e.g. a worker): the engine cannot create an offscreen swapchain there.
Future<int> createOffscreenSwapChain(int jobThreadAddress, int engineAddress, {bool hasStencilBuffer = false}) async {
  var flags = bindings.TSWAP_CHAIN_CONFIG_TRANSPARENT | bindings.TSWAP_CHAIN_CONFIG_READABLE;
  if (hasStencilBuffer) {
    flags |= bindings.TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;
  }
  // Created as a job on the engine's thread, like
  // Engine_createSwapChainJobThread: the engine resolves its viewer canvas
  // from the running job.
  final swapChain = await bindings.withPointerCallback<bindings.TSwapChain>(
    (cb) => bindings.Thermion_createOffscreenSwapChainJobThread(
      bindings.Pointer<bindings.TJobThread>.fromAddress(jobThreadAddress),
      bindings.Pointer<bindings.TEngine>.fromAddress(engineAddress),
      flags,
      cb,
    ),
  );
  if (swapChain == bindings.nullptr) {
    throw Exception('Failed to create offscreen swapchain: the page has no document body for the hidden canvas.');
  }
  return swapChain.address;
}
