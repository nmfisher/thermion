// Real worker rAF + Filament integration. See README.md for build instructions.
import 'dart:async';
import 'package:thermion_dart/src/bindings/src/js_interop.dart';

@JS('thermion_dart._WebTest_attachScene')
external void _attachScene(int worker, int engine, int manager, int slot, int id, int callback);
@JS('thermion_dart._WebTest_frameId')
external void _frameId(int worker, int engine, int renderer, int callback);
@JS('thermion_dart._WebTest_destroyScene')
external void _destroyScene(int worker, int engine, int slot, int id, int callback);
@JS('thermion_dart._WebTest_liveWorkers')
external int _liveWorkers();
@JS('thermion_dart._WebTest_holdCurrentWorker')
external void _holdCurrentWorker(int worker);
@JS('thermion_dart._WebTest_releaseHeldWorker')
external void _releaseHeldWorker();
@JS('thermion_dart._WebTest_contextWidth')
external void _contextWidth(int worker, int engine, int callback);

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class _Engine {
  _Engine(this.slot, this.worker, this.engine, this.renderer, this.manager);
  final int slot;
  final Pointer<TJobThread> worker;
  final Pointer<TEngine> engine;
  final Pointer<TRenderer> renderer;
  final Pointer<TRenderManager> manager;

  static Future<_Engine> create(int slot) async {
    final selector = '#frame_canvas_$slot'.toNativeUtf8().cast<Char>();
    final worker = JobThread_createForCanvas(selector);
    free(selector);
    check(worker != nullptr, 'Worker creation failed');
    final engine = await withPointerCallback<TEngine>(
      (cb) => Engine_createJobThread(worker, 1, nullptr, nullptr, 1, false, cb),
    );
    final renderer = await withPointerCallback<TRenderer>((cb) => Engine_createRendererJobThread(worker, engine, cb));
    final manager = RenderManager_create(engine, renderer);
    RenderManager_attachToJobThread(worker, manager);
    await withVoidCallback(
      (id, cb) => _attachScene(worker.address, engine.address, manager.address, slot, id, cb.address),
    );
    return _Engine(slot, worker, engine, renderer, manager);
  }

  Future<int> frameId() =>
      withUInt32Callback((cb) => _frameId(worker.address, engine.address, renderer.address, cb.address));

  Future<void> destroy() async {
    // Intentionally destroy while rAF is active: queued detachment must finish
    // before freeing the view/swapchain/renderer that tick() used to access.
    RenderManager_detachFromJobThread(worker, manager);
    await withVoidCallback((id, cb) => RenderManager_destroyJobThread(worker, manager, id, cb));
    await withVoidCallback((id, cb) => _destroyScene(worker.address, engine.address, slot, id, cb.address));
    await withVoidCallback((id, cb) => Engine_destroyRendererJobThread(worker, engine, renderer, id, cb));
    await withVoidCallback((id, cb) => Engine_destroyJobThread(worker, engine, id, cb));
    JobThread_destroy(worker);
  }
}

Future<List<int>> sample(_Engine first, _Engine second) async {
  final before = await Future.wait([first.frameId(), second.frameId()]);
  await Future<void>.delayed(const Duration(seconds: 1));
  final after = await Future.wait([first.frameId(), second.frameId()]);
  return [after[0] - before[0], after[1] - before[1]];
}

Future<void> verifyCanvasRouting() async {
  final firstSelector = '#creation_canvas_a'.toNativeUtf8().cast<Char>();
  final firstWorker = JobThread_createForCanvas(firstSelector);
  free(firstSelector);
  check(firstWorker != nullptr, 'First routing worker failed to start');
  _holdCurrentWorker(firstWorker.address);
  late final Future<Pointer<TEngine>> firstPending;
  late final Pointer<TJobThread> secondWorker;
  try {
    final secondSelector = '#creation_canvas_b'.toNativeUtf8().cast<Char>();
    secondWorker = JobThread_createForCanvas(secondSelector);
    free(secondSelector);
    check(secondWorker != nullptr, 'Second routing worker failed to start');
    // Submit after creating B. The explicit handle must still select A.
    firstPending = withPointerCallback<TEngine>(
      (cb) => Engine_createJobThread(firstWorker, 1, nullptr, nullptr, 1, false, cb),
    );
  } finally {
    _releaseHeldWorker();
  }
  // Worker B now exists. Engine A must still create its context on worker A.
  final first = await firstPending;
  check(first != nullptr, 'Delayed engine used the wrong canvas');
  final second = await withPointerCallback<TEngine>(
    (cb) => Engine_createJobThread(secondWorker, 1, nullptr, nullptr, 1, false, cb),
  );
  check(second != nullptr, 'Second routing engine failed to start');
  final widths = await Future.wait([
    withUInt32Callback((cb) => _contextWidth(firstWorker.address, first.address, cb.address)),
    withUInt32Callback((cb) => _contextWidth(secondWorker.address, second.address, cb.address)),
  ]);
  check(widths[0] == 16 && widths[1] == 32, 'Contexts used the wrong canvases: $widths');

  // Images have no engine handle. They must also use the supplied thread.
  _holdCurrentWorker(firstWorker.address);
  var firstFinished = false;
  final firstImage = withPointerCallback<TLinearImage>(
    (cb) => Image_createEmptyJobThread(firstWorker, 1, 1, 3, cb),
  ).then((image) {
    firstFinished = true;
    return image;
  });
  late final Pointer<TLinearImage> secondImage;
  try {
    secondImage = await withPointerCallback<TLinearImage>(
      (cb) => Image_createEmptyJobThread(secondWorker, 1, 1, 3, cb),
    );
    check(!firstFinished, 'An image job ran on B instead of waiting on A');
  } finally {
    _releaseHeldWorker();
  }
  final imageOnFirst = await firstImage;
  await withVoidCallback((id, cb) => Image_destroyJobThread(firstWorker, imageOnFirst, id, cb));
  await withVoidCallback((id, cb) => Image_destroyJobThread(secondWorker, secondImage, id, cb));
  await withVoidCallback((id, cb) => Engine_destroyJobThread(firstWorker, first, id, cb));
  await withVoidCallback((id, cb) => Engine_destroyJobThread(secondWorker, second, id, cb));
  JobThread_destroy(firstWorker);
  JobThread_destroy(secondWorker);
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (_liveWorkers() != 0 && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  check(_liveWorkers() == 0, 'Routing workers remained alive');
}

Future<void> main() async {
  try {
    await (globalContext['__thermionReady'] as JSPromise).toDart;
    NativeLibrary.initBindings('thermion_dart');
    await verifyCanvasRouting();
    final first = await _Engine.create(0);
    final second = await _Engine.create(1);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final initial = await sample(first, second);
    check(initial[0] > 0 && initial[1] > 0, 'Both engines must draw: $initial');

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
    globalContext['testResult'] = 'PASS: two engines drawing, pause/resume, independent teardown and worker exit'.toJS;
  } catch (error, stack) {
    globalContext['testResult'] = 'FAIL: $error\n$stack'.toJS;
  }
}
