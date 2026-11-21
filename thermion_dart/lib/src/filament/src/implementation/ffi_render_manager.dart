import 'dart:async';

import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

/// Tracks view-to-swapchain associations separately from whether a view should
/// currently be submitted for rendering.
///
/// A view can be paused before its platform surface exists. Keeping that state
/// independent of the attachment lets a later Android surface callback attach
/// the correct swapchain without accidentally enabling the view.
class RenderAttachmentState {
  final _attachments = <Pointer<TSwapChain>, List<(int, View)>>{};
  final _renderable = <View, bool>{};

  /// Last ordered renderable view list pushed to native for each swapchain.
  /// Used by [dirtyRenderableSnapshot] to skip syncing swapchains whose
  /// renderable list has not changed.
  final _syncedViews = <Pointer<TSwapChain>, List<View>>{};

  static void _stableSortByOrder(List<(int, View)> views) {
    if (views.length <= 1) return;
    // Insertion sort preserves relative order for equal renderOrder values
    // across all attachment counts (Dart's List.sort is unstable above 32).
    for (int i = 1; i < views.length; i++) {
      final current = views[i];
      int j = i - 1;
      while (j >= 0 && views[j].$1 > current.$1) {
        views[j + 1] = views[j];
        j--;
      }
      views[j + 1] = current;
    }
  }

  void attach(View view, Pointer<TSwapChain> swapChain, {int renderOrder = 0}) {
    final views = _attachments.putIfAbsent(swapChain, () => []);
    final existingIndex = views.indexWhere((entry) => entry.$2 == view);
    if (existingIndex != -1) {
      if (views[existingIndex].$1 == renderOrder) {
        return;
      }
      views.removeAt(existingIndex);
    }
    views.add((renderOrder, view));
    _stableSortByOrder(views);
  }

  void setAttachments(Pointer<TSwapChain> swapChain, List<({View view, int order})> attachments) {
    final next = <(int, View)>[];
    for (final attachment in attachments) {
      next.removeWhere((entry) => entry.$2 == attachment.view);
      next.add((attachment.order, attachment.view));
    }
    _stableSortByOrder(next);
    if (next.isEmpty) {
      _attachments.remove(swapChain);
    } else {
      _attachments[swapChain] = next;
    }
  }

  void updateAttachments(
    Pointer<TSwapChain> swapChain, {
    Iterable<({View view, int order})> attach = const [],
    Iterable<View> detach = const [],
  }) {
    final detachSet = detach is Set<View> ? detach : detach.toSet();
    final views = _attachments[swapChain];
    if (views != null && detachSet.isNotEmpty) {
      views.removeWhere((entry) => detachSet.contains(entry.$2));
    }
    for (final attachment in attach) {
      this.attach(attachment.view, swapChain, renderOrder: attachment.order);
    }
  }

  void setRenderable(View view, bool renderable) {
    _renderable[view] = renderable;
  }

  void setRenderables(Map<View, bool> renderability) {
    _renderable.addAll(renderability);
  }

  void detach(View view, {Pointer<TSwapChain>? swapChain}) {
    if (swapChain == null) {
      for (final views in _attachments.values) {
        views.removeWhere((entry) => entry.$2 == view);
      }
      _renderable.remove(view);
      return;
    }
    _attachments[swapChain]?.removeWhere((entry) => entry.$2 == view);
  }

  void detachAll(Pointer<TSwapChain> swapChain) {
    _attachments.remove(swapChain);
    _syncedViews.remove(swapChain);
  }

  Map<Pointer<TSwapChain>, List<(int, View)>> renderableSnapshot() {
    return {
      for (final entry in _attachments.entries)
        entry.key: entry.value.where((attachment) => _renderable[attachment.$2] ?? true).toList(),
    };
  }

  /// Returns the currently renderable views attached to [swapChain] in
  /// `renderOrder` order (excluding paused views where `_renderable[view]` is
  /// `false`). This is the exact ordered list passed to native
  /// `RenderManager_setRenderable`.
  List<View> _renderableViewsFor(Pointer<TSwapChain> swapChain) {
    final attachments = _attachments[swapChain];
    if (attachments == null || attachments.isEmpty) {
      return const [];
    }
    return [
      for (final attachment in attachments)
        if (_renderable[attachment.$2] ?? true) attachment.$2,
    ];
  }

  static bool _viewListsEqual(List<View> a, List<View> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Returns an ordered renderable view list for each swapchain whose
  /// renderable list differs from the last synced state in [_syncedViews].
  ///
  /// Swapchains that previously synced non-empty views and now have none are
  /// included with an empty list so native clears their view vector once.
  Map<Pointer<TSwapChain>, List<View>> dirtyRenderableSnapshot() {
    final dirty = <Pointer<TSwapChain>, List<View>>{};
    final swapChains = <Pointer<TSwapChain>>{..._attachments.keys, ..._syncedViews.keys};
    for (final swapChain in swapChains) {
      final current = _renderableViewsFor(swapChain);
      final synced = _syncedViews[swapChain] ?? const <View>[];
      if (!_viewListsEqual(current, synced)) {
        dirty[swapChain] = List<View>.unmodifiable(current);
      }
    }
    return dirty;
  }

  /// Records that [views] has been synchronized to native for [swapChain].
  void markSynced(Pointer<TSwapChain> swapChain, List<View> views) {
    if (views.isEmpty) {
      _syncedViews.remove(swapChain);
    } else {
      _syncedViews[swapChain] = List<View>.unmodifiable(views);
    }
  }

  ({Map<Pointer<TSwapChain>, List<(int, View)>> attachments, Map<View, bool> renderable}) _saveState() => (
    attachments: {for (final entry in _attachments.entries) entry.key: List<(int, View)>.of(entry.value)},
    renderable: Map<View, bool>.of(_renderable),
  );

  void _restoreState(({Map<Pointer<TSwapChain>, List<(int, View)>> attachments, Map<View, bool> renderable}) saved) {
    _attachments
      ..clear()
      ..addAll(saved.attachments);
    _renderable
      ..clear()
      ..addAll(saved.renderable);
  }

  List<ViewAttachment> getViewAttachments(Pointer<TSwapChain> swapChain) {
    final attachments = _attachments[swapChain] ?? const <(int, View)>[];
    return List.unmodifiable(
      attachments.map(
        (attachment) =>
            ViewAttachment(view: attachment.$2, order: attachment.$1, renderable: _renderable[attachment.$2] ?? true),
      ),
    );
  }

  Iterable<View> getAttachedViews(Pointer<TSwapChain> swapChain) =>
      _attachments[swapChain]?.map((entry) => entry.$2) ?? [];

  Iterable<Pointer<TSwapChain>> getAttachedSwapChains(View view) sync* {
    for (final entry in _attachments.entries) {
      if (entry.value.any((attachment) => attachment.$2 == view)) {
        yield entry.key;
      }
    }
  }

  void clear() {
    _attachments.clear();
    _renderable.clear();
    _syncedViews.clear();
  }
}

class FFIRenderManager extends RenderManager<Pointer<TRenderManager>> {
  /// Native `RenderManager_setRenderable` passes view count as `uint8_t`.
  static const int maxRenderableViewsPerSwapChain = 255;

  final Pointer<TRenderManager> pointer;

  /// The owning app. The RenderManager wraps engine-bound resources (a
  /// Renderer created from the Engine) and is only valid while that engine is
  /// alive. It also reconstructs `FFISwapChain` wrappers for attached
  /// swapchains, which need the same app.
  final FFIFilamentApp app;

  Pointer<TRenderManager> getNativeHandle() {
    return pointer;
  }

  late final _logger = Logger(this.runtimeType.toString());

  FFIRenderManager(this.pointer, this.app);

  /// Per-engine view/swapchain attachment state.
  ///
  /// This must NOT be static: on web each viewer owns its own engine and its
  /// own `FFIRenderManager`, and `_syncViews` pushes every entry in this map
  /// into `pointer`'s native RenderManager. A shared map makes app1's attach
  /// push app0's swapchain/view into app1's render manager; app1's worker then
  /// calls `beginFrame` on a swapchain owned by a different engine/WebGL
  /// context and wedges on its next rAF tick, so every subsequent op on app1
  /// hangs (the second-viewer quickstart hang). Per-engine state also means
  /// `destroy()` on one app no longer clears another app's attachments.
  final _attachmentState = RenderAttachmentState();

  /// Serialises every operation that mutates attachment state and runs
  /// `_syncViews` (attach / detach / detachAll). Concurrent calls from
  /// sibling viewers in multi-viewer apps were running in parallel,
  /// each taking its own `_syncViews` snapshot at a different moment.
  /// One viewer's snapshot could include another viewer's view that
  /// was being concurrently destroyed via `destroyView`; the
  /// `setRenderable` call then passed a dangling native pointer to
  /// Filament and the process took a SIGSEGV at the next access.
  ///
  /// Serialising means each attach/detach/_syncViews completes before
  /// the next can begin — the snapshot it takes is always a stable
  /// view of the world for the duration of its setRenderable round-
  /// trips. View destruction (which awaits `detach(view)` first via
  /// `destroyView`) cannot interleave inside another viewer's sync.
  ///
  /// Deliberately static (module-wide, not per-engine): cross-engine attach /
  /// detach ordering was the source of the original multi-viewer SIGSEGV, and
  /// with per-engine attachment state the chain only orders quick per-engine
  /// round-trips — each op still dispatches to its own worker via `pointer`.
  static Future<void> _opChain = Future.value();

  Future<T> _serialize<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    final prev = _opChain;
    _opChain = completer.future.then((_) {}, onError: (_) {});
    return prev.then((_) async {
      try {
        final result = await op();
        completer.complete(result);
        return result;
      } catch (e, st) {
        completer.completeError(e, st);
        rethrow;
      }
    });
  }

  void _validateDirtyViews(Map<Pointer<TSwapChain>, List<View>> dirty) {
    for (final views in dirty.values) {
      if (views.length > maxRenderableViewsPerSwapChain) {
        throw RangeError.range(
          views.length,
          0,
          maxRenderableViewsPerSwapChain,
          'views',
          'RenderManager supports at most $maxRenderableViewsPerSwapChain renderable views per swapchain',
        );
      }
    }
  }

  Future<void> _mutate(void Function() mutation) {
    return _serialize(() async {
      final saved = _attachmentState._saveState();
      final Map<Pointer<TSwapChain>, List<View>> dirty;
      try {
        mutation();
        dirty = _attachmentState.dirtyRenderableSnapshot();
        _validateDirtyViews(dirty);
      } catch (_) {
        _attachmentState._restoreState(saved);
        rethrow;
      }
      await _syncViews(dirty);
    });
  }

  @override
  Future attach(View view, SwapChain swapChain, {int renderOrder = 0}) =>
      _mutate(() => _attachmentState.attach(view, swapChain.getNativeHandle(), renderOrder: renderOrder));

  @override
  Future setAttachments(SwapChain swapChain, List<({View view, int order})> attachments) =>
      _mutate(() => _attachmentState.setAttachments(swapChain.getNativeHandle(), attachments));

  @override
  Future updateAttachments(
    SwapChain swapChain, {
    Iterable<({View view, int order})> attach = const [],
    Iterable<View> detach = const [],
  }) => _mutate(() => _attachmentState.updateAttachments(swapChain.getNativeHandle(), attach: attach, detach: detach));

  @override
  Future setRenderable(View view, bool renderable) => setRenderables({view: renderable});

  @override
  Future setRenderables(Map<View, bool> renderability) => _mutate(() => _attachmentState.setRenderables(renderability));

  @override
  Future detach(View view, {SwapChain? swapChain}) =>
      _mutate(() => _attachmentState.detach(view, swapChain: swapChain?.getNativeHandle()));

  Future<void> _syncSwapChain(Pointer<TSwapChain> swapChainHandle, List<View> views) async {
    final Pointer<PointerClass<TView>> viewPointers;
    if (views.isEmpty) {
      viewPointers = nullptr.cast();
    } else {
      final pointers = allocate<PointerClass>(views.length * sizeOf<PointerClass>());
      for (int i = 0; i < views.length; i++) {
        pointers[i] = views[i].getNativeHandle();
      }
      viewPointers = pointers.cast();
    }

    try {
      await withVoidCallback(
        (requestId, cb) => RenderManager_setRenderableJobThread(
          app.jobThreadHandle,
          pointer,
          swapChainHandle,
          viewPointers,
          views.length,
          requestId,
          cb,
        ),
      );
    } finally {
      if (views.isNotEmpty) {
        free(viewPointers);
      }
    }
    _logger.fine("""Synced ${views.length} views for swapchain $swapChainHandle""");
  }

  Future _syncViews([Map<Pointer<TSwapChain>, List<View>>? dirtySnapshot]) async {
    // Snapshot the keys and per-key view list BEFORE iterating.
    // Even though mutations are serialized on `_opChain`, taking a snapshot
    // avoids mutating live collections across async round-trips.
    final dirty = dirtySnapshot ?? _attachmentState.dirtyRenderableSnapshot();
    _validateDirtyViews(dirty);

    for (final entry in dirty.entries) {
      await _syncSwapChain(entry.key, entry.value);
      _attachmentState.markSynced(entry.key, entry.value);
    }
  }

  @override
  Future detachAll(SwapChain swapChain) {
    return _serialize(() async {
      final swapChainHandle = swapChain.getNativeHandle();
      await withVoidCallback(
        (requestId, cb) =>
            RenderManager_removeSwapChainJobThread(app.jobThreadHandle, pointer, swapChainHandle, requestId, cb),
      );
      _attachmentState.detachAll(swapChainHandle);
    });
  }

  @override
  Future<void> destroy() => _serialize(() async {
    await withVoidCallback((requestId, callback) {
      RenderManager_destroyJobThread(app.jobThreadHandle, pointer, requestId, callback);
    });
    _attachmentState.clear();
  });

  Future render({int? frameTimeInNanos}) async {
    // Previously there was a check here for running on web (and if so, the method simply returned
    // because the compiled Thermion web library managed its own main loop & frame rendering).
    // This check has been moved to JobThread (which decides whether its worker owns rendering or this call
    // drives a frame on the calling thread. Worker mode completes without queuing work).
    final timestamp = frameTimeInNanos ?? FrameScheduler_steadyClockUs().toInt() * 1000;
    await withVoidCallback((requestId, cb) {
      RenderManager_renderJobThread(app.jobThreadHandle, pointer, timestamp.toBigInt, requestId, cb);
    });
  }

  @override
  Iterable<View> getAttachedViews(SwapChain swapChain) {
    return getViewAttachments(swapChain).map((attachment) => attachment.view);
  }

  @override
  List<ViewAttachment> getViewAttachments(SwapChain swapChain) {
    return _attachmentState.getViewAttachments(swapChain.getNativeHandle());
  }

  @override
  Iterable<SwapChain> getAttachedSwapChains(View view) sync* {
    for (final handle in _attachmentState.getAttachedSwapChains(view)) {
      yield FFISwapChain(handle, app);
    }
  }
}
