import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

class FFISwapChain extends SwapChain<Pointer<TSwapChain>> {
  final Pointer<TSwapChain> pointer;

  /// The owning app. A SwapChain is an Engine resource (created by
  /// `engine->createSwapChain`) and is only valid while that engine is alive;
  /// holding the app makes that lifetime coupling explicit rather than
  /// implicit, matching the other engine-bound FFI wrappers.
  final FFIFilamentApp _app;

  Pointer<TSwapChain> getNativeHandle() => pointer;

  FFISwapChain(this.pointer, this._app);
}
