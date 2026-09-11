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

  /// Renders the attached views and swapchains.
  ///
  /// On native platforms, [frameTimeInNanos] is a frame timestamp in nanoseconds
  /// on the native steady clock, as supplied by Thermion's frame scheduler.
  /// It is not a date, wall-clock time, or Flutter's adjusted animation time.
  /// When omitted, uses the current native steady-clock time. The returned
  /// [Future] completes when the render pipeline step has finished.
  ///
  /// On web, queues rendering for browser animation frames and returns without
  /// waiting for completion. [frameTimeInNanos] is ignored on that path.
  Future render({int? frameTimeInNanos});

  /// Detaches this manager from the render worker and destroys it after earlier
  /// queued work. Await this before destroying its animation managers, renderer,
  /// or engine. Stop submitting work to this manager before calling destroy.
  ///
  /// Completion means the manager has been deleted; it does not shut down the
  /// worker. Engine and worker teardown are owned by the Filament app.
  Future<void> destroy();
}
