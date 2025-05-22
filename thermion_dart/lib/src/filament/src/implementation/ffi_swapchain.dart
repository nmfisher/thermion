import 'package:thermion_dart/thermion_dart.dart';

class FFISwapChain extends SwapChain {
  final Pointer<TSwapChain> swapChain;

  FFISwapChain(this.swapChain);
}
