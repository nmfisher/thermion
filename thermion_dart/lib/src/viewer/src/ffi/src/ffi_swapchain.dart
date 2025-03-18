import 'dart:ffi';

import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFISwapChain extends SwapChain {
  final Pointer<TSwapChain> swapChain;

  FFISwapChain(this.swapChain);
}
