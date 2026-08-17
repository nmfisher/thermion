import 'dart:async';

import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/src/filament/src/interface/render_manager.dart';
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

  void attach(View view, Pointer<TSwapChain> swapChain, {int renderOrder = 0}) {
    final views = _attachments.putIfAbsent(swapChain, () => []);
    views.removeWhere((entry) => entry.$2 == view);
    views.add((renderOrder, view));
    views.sort((a, b) => a.$1.compareTo(b.$1));
  }

  void setRenderable(View view, bool renderable) {
    _renderable[view] = renderable;
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
  }

  Map<Pointer<TSwapChain>, List<(int, View)>> activeSnapshot() {
    return {
      for (final entry in _attachments.entries)
        entry.key: entry.value.where((attachment) => _renderable[attachment.$2] ?? true).toList(),
    };
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
  }
}

class FFIRenderManager extends RenderManager<Pointer<TRenderManager>> {
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

  @override
  Future attach(View view, SwapChain swapChain, {int renderOrder = 0}) {
    return _serialize(() async {
      _attachmentState.attach(view, swapChain.getNativeHandle(), renderOrder: renderOrder);
      await _syncViews();
    });
  }

  @override
  Future setRenderable(View view, bool renderable) {
    return _serialize(() async {
      _attachmentState.setRenderable(view, renderable);
      await _syncViews();
    });
  }

  @override
  Future detach(View view, {SwapChain? swapChain}) {
    return _serialize(() async {
      _attachmentState.detach(view, swapChain: swapChain?.getNativeHandle());
      await _syncViews();
    });
  }

  Future _syncViews() async {
    // Snapshot the keys and the per-key view list BEFORE iterating.
    // Concurrent `attach` / `detach` calls (common in multi-viewer
    // apps where multiple viewers mount or dispose at the same time)
    // mutate `_attachments` while we await on the render thread
    // round-trip. A naive `for (final h in _attachments.keys) { … }`
    // loop yields to the event loop on the await, lets a concurrent
    // attach/detach modify the live map, then resumes with stale
    // iterator state — `_syncViews` ends up pushing inconsistent
    // view lists to C++ RenderManager (some swap chains skipped,
    // others written with old data). The downstream symptom is the
    // `endFrame:490 — SwapChain must remain valid` precondition
    // when the render iteration touches the inconsistent state.
    //
    // Snapshotting also tolerates removal: if an entry was deleted
    // by the time we get back to it, the views list will be null
    // and we skip it.
    final snapshot = _attachmentState.activeSnapshot();

    for (final swapChainHandle in snapshot.keys) {
      final views = snapshot[swapChainHandle];
      if (views == null) continue;
      final pointers = allocate<PointerClass>(views.length * sizeOf<PointerClass>());
      for (int i = 0; i < views.length; i++) {
        pointers[i] = views[i].$2.getNativeHandle();
      }

      await withVoidCallback(
        (requestId, cb) => RenderManager_setRenderableRenderThread(
          pointer,
          swapChainHandle,
          pointers.cast(),
          views.length,
          requestId,
          cb,
        ),
      );

      free(pointers);
      _logger.fine("""Synced ${views.length} views for swapchain $swapChainHandle""");
    }
  }

  Future detachAll(SwapChain swapChain) {
    return _serialize(() async {
      await withVoidCallback(
        (requestId, cb) =>
            RenderManager_removeSwapChainRenderThread(pointer, swapChain.getNativeHandle(), requestId, cb),
      );
      _attachmentState.detachAll(swapChain.getNativeHandle());
    });
  }

  void destroy() {
    _attachmentState.clear();
    RenderManager_destroy(pointer);
  }

  Future render() async {
    if (FILAMENT_SINGLE_THREADED) {
      // Web: fire-and-forget. The render completes across the next N rAF
      // cycles (N = number of swapchains) driven by RenderThread::iter()
      // calling RenderManager::tick(). We cannot await completion without
      // deadlocking the worker's main loop from the main browser thread,
      // and pre-refactor web was already fire-and-forget via requestFrame.
      RenderManager_requestRender(pointer);
    } else {
      final frameTimeInNanos = DateTime.now().microsecondsSinceEpoch * 1000;

      await withVoidCallback((requestId, cb) {
        RenderManager_renderRenderThread(pointer, frameTimeInNanos.toBigInt, requestId, cb);
      });
    }
  }

  @override
  Iterable<View> getAttachedViews(SwapChain swapChain) {
    return _attachmentState.getAttachedViews(swapChain.getNativeHandle());
  }

  @override
  Iterable<SwapChain> getAttachedSwapChains(View view) sync* {
    for (final handle in _attachmentState.getAttachedSwapChains(view)) {
      yield FFISwapChain(handle, app);
    }
  }
}
