// Real worker rAF + Filament integration. See README.md for build instructions.
import 'dart:async';
import 'package:thermion_dart/src/bindings/src/js_interop.dart';

@JS('thermion_dart._WebTest_attachScene')
external void _attachScene(int engine, int manager, int slot, int id, int callback);
@JS('thermion_dart._WebTest_frameId')
external void _frameId(int engine, int renderer, int callback);
@JS('thermion_dart._WebTest_destroyScene')
external void _destroyScene(int engine, int slot, int id, int callback);
@JS('thermion_dart._WebTest_liveWorkers')
external int _liveWorkers();

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class _Engine {
  _Engine(this.slot, this.worker, this.engine, this.renderer, this.manager);
  final int slot;
  final Pointer<Void> worker;
  final Pointer<TEngine> engine;
  final Pointer<TRenderer> renderer;
  final Pointer<TRenderManager> manager;

  static Future<_Engine> create(int slot, int fps) async {
    final selector = '#frame_canvas_$slot'.toNativeUtf8().cast<Char>();
    final worker = RenderThread_createForCanvas(selector);
    free(selector);
    check(worker != nullptr, 'Worker creation failed');
    final engine = await withPointerCallback<TEngine>(
      (cb) => Engine_createRenderThread(1, nullptr, nullptr, 1, false, cb),
    );
    final renderer = await withPointerCallback<TRenderer>((cb) => Engine_createRendererRenderThread(engine, cb));
    final manager = RenderManager_create(engine, renderer);
    RenderManager_attachToRenderThread(manager);
    RenderManager_setTargetFps(manager, fps);
    await withVoidCallback((id, cb) => _attachScene(engine.address, manager.address, slot, id, cb.address));
    return _Engine(slot, worker, engine, renderer, manager);
  }

  Future<int> frameId() => withUInt32Callback((cb) => _frameId(engine.address, renderer.address, cb.address));

  Future<void> destroy() async {
    // Intentionally destroy while rAF is active: queued detachment must finish
    // before freeing the view/swapchain/renderer that tick() used to access.
    await withVoidCallback((id, cb) => RenderManager_destroyRenderThread(manager, id, cb));
    await withVoidCallback((id, cb) => _destroyScene(engine.address, slot, id, cb.address));
    await withVoidCallback((id, cb) => Engine_destroyRendererRenderThread(engine, renderer, id, cb));
    await withVoidCallback((id, cb) => Engine_destroyRenderThread(engine, id, cb));
    RenderThread_destroy(worker);
  }
}

Future<List<int>> sample(_Engine first, _Engine second) async {
  final before = await Future.wait([first.frameId(), second.frameId()]);
  await Future<void>.delayed(const Duration(seconds: 1));
  final after = await Future.wait([first.frameId(), second.frameId()]);
  return [after[0] - before[0], after[1] - before[1]];
}

Future<void> main() async {
  try {
    await (globalContext['__thermionReady'] as JSPromise).toDart;
    NativeLibrary.initBindings('thermion_dart');
    final first = await _Engine.create(0, 30);
    final second = await _Engine.create(1, 10);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final initial = await sample(first, second);
    check(initial[0] > initial[1] * 1.5 && initial[1] >= 5, 'Independent 30/10 FPS limits failed: $initial');
    check(initial[0] <= 34 && initial[1] <= 14, 'FPS limits exceeded: $initial');

    RenderManager_setTargetFps(first.manager, 10);
    RenderManager_setTargetFps(second.manager, 30);
    final changed = await sample(first, second);
    check(changed[1] > changed[0] * 1.5 && changed[0] >= 5, 'Changed 10/30 FPS limits failed: $changed');
    check(changed[0] <= 14 && changed[1] <= 34, 'Changed FPS limits exceeded: $changed');

    RenderManager_setPaused(first.manager, true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final paused = await sample(first, second);
    check(paused[0] == 0 && paused[1] >= 5, 'Pause affected the wrong engine: $paused');
    RenderManager_setPaused(first.manager, false);
    final resumed = await sample(first, second);
    check(resumed[0] >= 5, 'Paused engine failed to resume: $resumed');

    await first.destroy();
    final before = await second.frameId();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    check(await second.frameId() > before, 'Destroying one engine stopped the other');
    await second.destroy();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (_liveWorkers() != 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    check(_liveWorkers() == 0, 'Workers remained alive after teardown');
    globalContext['testResult'] =
        'PASS: real drawing, per-engine FPS $initial / $changed, pause/resume, independent teardown'.toJS;
  } catch (error, stack) {
    globalContext['testResult'] = 'FAIL: $error\n$stack'.toJS;
  }
}
