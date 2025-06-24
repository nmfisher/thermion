import 'package:thermion_dart/thermion_dart.dart';

class FFISwapChain extends SwapChain<Pointer> {
  
  final Pointer<TSwapChain> pointer;

  T getNativeHandle<T>() => pointer as T;

  FFISwapChain(this.pointer);
  
}
