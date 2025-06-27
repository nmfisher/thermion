import 'package:thermion_dart/thermion_dart.dart';

class FFISwapChain extends SwapChain<Pointer<TSwapChain>> {
  
  final Pointer<TSwapChain> pointer;

  Pointer<TSwapChain> getNativeHandle() => pointer;

  FFISwapChain(this.pointer);
  
}
