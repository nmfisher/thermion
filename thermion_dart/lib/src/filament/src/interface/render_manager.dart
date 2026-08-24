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

  Future render();

  void destroy();
}
