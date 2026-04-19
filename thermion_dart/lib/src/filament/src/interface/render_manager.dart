import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

abstract class RenderManager<T> extends NativeHandle<T> {
  Future attach(View view, SwapChain swapChain, { int renderOrder = 0});
  Future detach(View view, {SwapChain? swapChain});
  Future detachAll(SwapChain swapChain);
  Iterable<View> getAttachedViews(SwapChain swapChain);
  Iterable<SwapChain> getAttachedSwapChains(View view);
  
  Future render();

  void destroy();

  static RenderManager? _instance;
  static RenderManager get instance => _instance!;
}
