/// Offscreen swapchain plumbing for `thermion_dart_web.dart`.
///
/// The conditional export keeps `thermion_dart_web.dart` analyzable on
/// native hosts: the io variant reports the feature unavailable, the web
/// variant (compiled only under dart2js/dart2wasm) talks to the engine's
/// offscreen entry point and hidden canvas.
///
/// Handles cross this interface as raw int addresses (`Pointer.address`):
/// [jobThreadAddress] is the engine's job thread, [engineAddress] the
/// engine, and [createOffscreenSwapChain] returns the new swapchain. Keeping
/// them ints avoids the two platforms' incompatible Pointer types; the
/// caller adopts the swapchain through `FFIFilamentApp`.
library;

export 'offscreen_swapchain_io.dart' if (dart.library.js_interop) 'offscreen_swapchain_web.dart';
