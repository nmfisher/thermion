/// Raw swapchain-flag word for `FFIFilamentApp.createSwapChainFromFlags`.
///
/// The generated bindings disagree on the flag type: native ffi uses `int`
/// for `uint64_t`, the web js_interop bindings use `BigInt`. Each platform
/// forwards its own word unchanged; the conditional export keeps both
/// analyzable from platform-neutral code.
export 'swapchain_flags_io.dart' if (dart.library.js_interop) 'swapchain_flags_web.dart';
