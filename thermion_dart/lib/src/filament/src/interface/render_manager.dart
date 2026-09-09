import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Describes a [View] registered for rendering against a [SwapChain].
///
/// Attachments are ordered independently for each swapchain. They remain in
/// the attachment list when [renderable] is false, allowing rendering to be
/// suspended without losing the association or render order.
class ViewAttachment {
  /// The attached view.
  final View view;

  /// The view's position in the swapchain's render sequence.
  ///
  /// Lower values render first. The relative order of attachments with the
  /// same value is unspecified.
  final int order;

  /// Whether [view] is currently submitted when its swapchain is rendered.
  ///
  /// This does not describe scene visibility and does not affect the view's
  /// render target. A non-renderable view is still attached.
  final bool renderable;

  const ViewAttachment({required this.view, required this.order, required this.renderable});
}

/// Coordinates frame submission for the views and swapchains owned by a
/// [FilamentApp].
///
/// A swapchain identifies a surface that can begin and end a frame. A view
/// describes what Filament should render. [attach] associates the two so that
/// [render] can submit the view between that swapchain's begin/end-frame
/// calls. Multiple views can be attached to the same swapchain and are
/// submitted in ascending [ViewAttachment.order]. A view may also be attached
/// to more than one swapchain.
///
/// Attachment controls *when* a view is submitted; it does not control *where*
/// the view draws. The latter is determined by [View.setRenderTarget] (or by
/// the swapchain when the view has no render target). Attaching or detaching a
/// view never changes its render target.
///
/// Renderability is separate from attachment. [setRenderable] temporarily
/// excludes a view from every swapchain to which it is attached, while
/// preserving those associations and their ordering. This is useful for
/// optional passes such as overlays, which should be cheap to suspend and
/// resume without rebuilding their resources.
///
/// For each rendered frame, the manager advances registered animations and
/// plugins once, then renders every swapchain that has at least one renderable
/// view. [FilamentApp.render] is the usual entry point because it runs Dart
/// request-frame hooks before delegating here.
///
/// The manager tracks associations but does not own the attached [View] or
/// [SwapChain] objects. Detach them before destroying those resources. Calls
/// that mutate attachment state are asynchronous because the updated view
/// lists must be synchronized with the render thread.
abstract class RenderManager<T> extends NativeHandle<T> {
  /// Associates [view] with [swapChain] for future calls to [render].
  ///
  /// Views with lower [renderOrder] values are submitted first. Attaching the
  /// same view to the same swapchain again updates its order rather than
  /// creating a duplicate attachment. Existing attachments to other
  /// swapchains are unaffected.
  ///
  /// A view is renderable by default unless a previous [setRenderable] call
  /// set its state before attachment. This method does not modify the view's
  /// render target or take ownership of either object.
  ///
  /// The current native manager submits at most eight renderable views per
  /// swapchain; additional renderable attachments are not rendered.
  Future attach(View view, SwapChain swapChain, {int renderOrder = 0});

  /// Includes or excludes [view] from frame submission.
  ///
  /// The setting applies to every swapchain to which [view] is attached. A
  /// value of `false` preserves the view's associations, render order, render
  /// target, and scene; it only prevents this manager from submitting it.
  ///
  /// The requested state is retained when the view has not been attached yet,
  /// so callers can configure a view before its platform surface exists.
  /// Await the returned future before assuming the render thread sees the new
  /// view list.
  Future setRenderable(View view, bool renderable);

  /// Applies several per-view renderability changes as one state update.
  ///
  /// All entries are applied to local attachment state before the updated
  /// lists are synchronized with the render thread. Synchronous readers such
  /// as [getViewAttachments] therefore do not observe partially-updated
  /// combinations when related views, such as a group of composite passes,
  /// are enabled or disabled together.
  ///
  /// As with [setRenderable], settings are retained for views that are not yet
  /// attached and each setting applies across all attachments of that view.
  Future setRenderables(Map<View, bool> renderability);

  /// Removes [view] from one or all swapchains.
  ///
  /// When [swapChain] is provided, only that association is removed and the
  /// view's renderability setting is retained for its other or future
  /// attachments. When it is omitted, every association is removed and the
  /// retained renderability setting is cleared, so a later attachment starts
  /// renderable by default.
  ///
  /// This method does not destroy the view or any swapchain. Await it before
  /// destroying [view], so the render thread cannot retain a dangling native
  /// view pointer.
  Future detach(View view, {SwapChain? swapChain});

  /// Removes every view attachment for [swapChain].
  ///
  /// Per-view renderability settings are retained, because the same views may
  /// remain attached to other swapchains or be attached again later. This
  /// method does not destroy the swapchain or its views. Await it before
  /// destroying [swapChain].
  Future detachAll(SwapChain swapChain);

  /// Returns an immutable, ordered copy of [swapChain]'s attachments.
  ///
  /// The list includes non-renderable views and is safe to retain across
  /// asynchronous work: later attachment or renderability changes do not
  /// alter it. Each entry records the state at the time of this call.
  ///
  /// This reads the manager's local state and does not wait for pending
  /// mutations. Await calls such as [attach], [detach], or [setRenderable]
  /// before reading when their completion matters.
  List<ViewAttachment> getViewAttachments(SwapChain swapChain);

  /// Returns all views currently attached to [swapChain] in render order.
  ///
  /// Non-renderable views are included. This is equivalent to mapping
  /// [ViewAttachment.view] over [getViewAttachments].
  Iterable<View> getAttachedViews(SwapChain swapChain);

  /// Returns every swapchain to which [view] is currently attached.
  ///
  /// The view is included regardless of its renderability. The order of the
  /// returned swapchains is unspecified.
  Iterable<SwapChain> getAttachedSwapChains(View view);

  /// Advances frame state and submits all currently renderable attachments.
  ///
  /// Animations and plugins are updated once for the frame. Each swapchain
  /// with renderable attachments then begins a frame, renders its views in
  /// ascending order, and ends the frame. Swapchains without renderable views
  /// are skipped.
  ///
  /// On native platforms the returned future completes after the render-thread
  /// operation. On web it requests rendering from the browser animation-frame
  /// loop and can complete before that frame is presented. Most callers should
  /// use [FilamentApp.render] so request-frame hooks run first.
  Future render();

  /// Destroys this manager and clears its attachment state.
  ///
  /// Attached views and swapchains are not destroyed. Normal application
  /// teardown should detach and destroy them through [FilamentApp] before
  /// destroying the manager. No method or native handle may be used after
  /// this call.
  void destroy();
}
