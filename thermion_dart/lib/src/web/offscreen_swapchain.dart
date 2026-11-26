/// Offscreen (present-skip) swapchain plumbing for
/// `thermion_dart_web.dart`.
///
/// The conditional export keeps `thermion_dart_web.dart` analyzable on
/// native hosts: the io variant reports the feature unavailable, the web
/// variant (compiled only under dart2js/dart2wasm) talks to the engine's
/// hidden canvas.
///
/// [window] is the raw native window handle address (`Pointer.address` on
/// native, a Wasm address int on web); 0/null means "the engine's own
/// canvas/window", like `createSwapChain(nullptr)` on web. Passing the
/// address as an int keeps this interface free of the two platforms'
/// incompatible Pointer types.
library;

export 'offscreen_swapchain_io.dart' if (dart.library.js_interop) 'offscreen_swapchain_web.dart';
