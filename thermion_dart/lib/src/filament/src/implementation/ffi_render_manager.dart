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

  @override
  Future attach(View view, SwapChain swapChain, {int renderOrder = 0}) async {
    final handle = swapChain.getNativeHandle();
    if (!_attachments.containsKey(handle)) {
      _attachments[handle] = [];
    }

    _attachments[handle]!.removeWhere((v) => v.$2 == view);
    _attachments[handle]!.add((renderOrder, view));
    _attachments[handle]!.sort((a, b) => a.$1.compareTo(b.$1));
    await _syncViews();
  }

  @override
  Future detach(View view, {SwapChain? swapChain}) async {
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
  }

  Future _syncViews() async {
    for (final swapChainHandle in _attachments.keys) {
      final views = _attachments[swapChainHandle]!;
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

  Future detachAll(SwapChain swapChain) async {
    await withVoidCallback((requestId, cb) =>
        RenderManager_removeSwapChainRenderThread(
            pointer, swapChain.getNativeHandle(), requestId, cb));
    _attachments.remove(swapChain.getNativeHandle());
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
