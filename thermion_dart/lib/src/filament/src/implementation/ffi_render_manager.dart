import 'dart:async';

import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/src/filament/src/interface/render_manager.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIRenderManager extends RenderManager<Pointer<TRenderManager>> {
  final Pointer<TRenderManager> pointer;

  Pointer<TRenderManager> getNativeHandle() {
    return pointer;
  }

  late final _logger = Logger(this.runtimeType.toString());

  FFIRenderManager(this.pointer);

  static final _attachments = <Pointer<TSwapChain>, List<(int, View)>>{};

  /// Serialises every operation that mutates `_attachments` and runs
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
      final handle = swapChain.getNativeHandle();
      if (!_attachments.containsKey(handle)) {
        _attachments[handle] = [];
      }

      _attachments[handle]!.removeWhere((v) => v.$2 == view);
      _attachments[handle]!.add((renderOrder, view));
      _attachments[handle]!.sort((a, b) => a.$1.compareTo(b.$1));
      await _syncViews();
    });
  }

  @override
  Future detach(View view, {SwapChain? swapChain}) {
    return _serialize(() async {
      if (swapChain == null) {
        for (final swapChainHandle in _attachments.keys) {
          _attachments[swapChainHandle]!.removeWhere((v) => v.$2 == view);
        }
      } else {
        if (!_attachments.containsKey(swapChain.getNativeHandle())) {
          _attachments[swapChain.getNativeHandle()] = [];
        }

        _attachments[swapChain.getNativeHandle()]!
            .removeWhere((v) => v.$2 == view);
      }
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
    final snapshot = <Pointer<TSwapChain>, List<(int, View)>>{};
    for (final entry in _attachments.entries) {
      snapshot[entry.key] = List.of(entry.value);
    }

    for (final swapChainHandle in snapshot.keys) {
      final views = snapshot[swapChainHandle];
      if (views == null) continue;
      final pointers = allocate<PointerClass>(views.length);
      for (int i = 0; i < views.length; i++) {
        pointers[i] = views[i].$2.getNativeHandle();
      }

      await withVoidCallback((requestId, cb) =>
          RenderManager_setRenderableRenderThread(pointer, swapChainHandle,
              pointers.cast(), views.length, requestId, cb));

      free(pointers);
      _logger.fine(
          """Synced ${views.length} views for swapchain $swapChainHandle""");
    }
  }

  Future detachAll(SwapChain swapChain) {
    return _serialize(() async {
      await withVoidCallback((requestId, cb) =>
          RenderManager_removeSwapChainRenderThread(
              pointer, swapChain.getNativeHandle(), requestId, cb));
      _attachments.remove(swapChain.getNativeHandle());
    });
  }

  void destroy() {
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
        RenderManager_renderRenderThread(
            pointer, frameTimeInNanos.toBigInt, requestId, cb);
      });
    }
  }

  @override
  Iterable<View> getAttachedViews(SwapChain swapChain) {
    return _attachments[swapChain.getNativeHandle()]?.map((v) => v.$2) ?? [];
  }

  @override
  Iterable<SwapChain> getAttachedSwapChains(View view) sync* {
    for (final entry in _attachments.entries) {
      for (final views in entry.value) {
        if (views.$2 == view) {
          yield FFISwapChain(entry.key);
        }
      }
    }
  }
}
