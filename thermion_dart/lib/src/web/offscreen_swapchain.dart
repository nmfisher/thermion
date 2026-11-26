/// Offscreen (present-skip) swapchain plumbing for
/// `thermion_dart_web.dart`.
///
/// The conditional export keeps `thermion_dart_web.dart` analyzable on
/// native hosts: the io variant reports the feature unavailable, the web
/// variant (compiled only under dart2js/dart2wasm) talks to the engine's
/// hidden canvas.
///
/// Handles cross this interface as raw int addresses (`Pointer.address`):
/// [jobThreadAddress] is the engine's job thread, [windowAddress] the native
/// window handle (0/null means "the engine's own canvas/window", like
/// `createSwapChain(nullptr)` on web). Keeping them ints avoids the two
/// platforms' incompatible Pointer types.
library;

export 'offscreen_swapchain_io.dart' if (dart.library.js_interop) 'offscreen_swapchain_web.dart';
