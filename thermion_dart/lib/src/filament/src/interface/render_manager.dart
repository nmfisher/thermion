import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// One ordered view attachment in a swapchain.
class ViewAttachment {
  final View view;
  final int order;
  final bool renderable;

  const ViewAttachment({required this.view, required this.order, required this.renderable});
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
  /// This avoids exposing intermediate state when a group of views is
  /// enabled or disabled together.
  Future setRenderables(Map<View, bool> renderability);

  Future detach(View view, {SwapChain? swapChain});
  Future detachAll(SwapChain swapChain);

  /// Returns a stable, ordered list of all attachments, including views that
  /// are currently not renderable.
  List<ViewAttachment> getViewAttachments(SwapChain swapChain);

  Iterable<View> getAttachedViews(SwapChain swapChain);
  Iterable<SwapChain> getAttachedSwapChains(View view);

  Future render();

  void destroy();
}
