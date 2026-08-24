import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// One ordered view attachment in a swapchain's render plan.
class RenderPass {
  final View view;
  final int order;
  final bool active;

  const RenderPass({required this.view, required this.order, required this.active});
}

/// Immutable snapshot of every ordered view attached to a swapchain.
///
/// A snapshot keeps capture and other frame-like operations consistent when
/// attachment state changes asynchronously. Inactive passes remain present so
/// their render targets can still be inspected without submitting them.
class RenderPlan {
  final List<RenderPass> passes;

  RenderPlan(Iterable<RenderPass> passes) : passes = List.unmodifiable(passes);

  Iterable<View> get attachedViews => passes.map((pass) => pass.view);

  Iterable<View> get activeViews => passes.where((pass) => pass.active).map((pass) => pass.view);

  RenderPass? passFor(View view) {
    for (final pass in passes) {
      if (pass.view == view) return pass;
    }
    return null;
  }
}

abstract class RenderManager<T> extends NativeHandle<T> {
  Future attach(View view, SwapChain swapChain, {int renderOrder = 0});

  /// Includes or excludes [view] from rendering while preserving its
  /// swapchain association.
  ///
  /// The requested state is retained when the view has not been attached yet,
  /// so platform surfaces can be created asynchronously.
  Future setRenderable(View view, bool renderable);

  /// Applies several renderability changes in one attachment-state update.
  ///
  /// This avoids exposing intermediate render plans when a group of passes is
  /// enabled or disabled together.
  Future setRenderables(Map<View, bool> renderability);

  Future detach(View view, {SwapChain? swapChain});
  Future detachAll(SwapChain swapChain);

  /// Returns one stable snapshot containing both active and inactive passes.
  RenderPlan getRenderPlan(SwapChain swapChain);

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
  /// The default web engine renders independently on its worker's animation
  /// frames: this method completes without requesting or waiting for a frame,
  /// and ignores [frameTimeInNanos]. A web engine built with
  /// THERMION_WEB_MAIN_THREAD instead renders on the calling thread.
  Future render({int? frameTimeInNanos});

  /// Detaches this manager and destroys it on its owning thread after earlier
  /// queued work. Await this before destroying its animation managers, renderer,
  /// or engine. Stop submitting work to this manager before calling destroy.
  ///
  /// Completion means the manager has been deleted; it does not shut down the
  /// worker. Engine and worker teardown are owned by the Filament app.
  Future<void> destroy();
}
