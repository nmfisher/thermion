import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

class FFISwapChain extends SwapChain<Pointer<TSwapChain>> {
  final Pointer<TSwapChain> pointer;

  Pointer<TSwapChain> getNativeHandle() => pointer;

  FFISwapChain(this.pointer, FFIFilamentApp _);
}
