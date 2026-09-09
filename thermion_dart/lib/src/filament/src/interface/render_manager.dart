import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

abstract class RenderManager<T> extends NativeHandle<T> {
  Future attach(View view, SwapChain swapChain, {int renderOrder = 0});

  /// Includes or excludes [view] from rendering while preserving its
  /// swapchain association.
  ///
  /// The requested state is retained when the view has not been attached yet,
  /// so platform surfaces can be created asynchronously.
  Future setRenderable(View view, bool renderable);

  Future detach(View view, {SwapChain? swapChain});
  Future detachAll(SwapChain swapChain);
  Iterable<View> getAttachedViews(SwapChain swapChain);
  Iterable<SwapChain> getAttachedSwapChains(View view);

  /// Renders at a frame timestamp in the native steady-clock time base.
  /// When omitted, rendering uses the current native steady-clock time.
  Future render({int? frameTimeInNanos});

  void destroy();
}
