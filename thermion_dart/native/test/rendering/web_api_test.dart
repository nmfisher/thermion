// Full-module browser smoke test. See README.md for compile/run commands.
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:thermion_dart/src/bindings/src/js_interop.dart';
import 'package:thermion_dart/thermion_dart.dart' show Backend, FilamentApp, ThermionViewerFFI, Vector3;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';

void progress(String message) => globalContext['testProgress'] = message.toJS;

Future<String?> readName(Pointer<TView> view) => withStringCallback((callback) {
  View_getNameJobThread(view, callback);
});

Future<void> main() async {
  try {
    progress('module initialization');
    await (globalContext['__thermionReady'] as JSPromise).toDart;
    NativeLibrary.initBindings('thermion_dart');
    for (var round = 0; round < 3; round++) {
      progress('engine $round creation');
      final selector = '#test_canvas_$round'.toNativeUtf8().cast<Char>();
      final worker = JobThread_createForCanvas(selector);
      free(selector);
      if (worker == nullptr) throw StateError('Worker creation failed');
      final engine = await withPointerCallback<TEngine>((cb) {
        Engine_createJobThread(1, nullptr, nullptr, 1, false, cb);
      });
      if (engine == nullptr) throw StateError('Engine creation failed');
      final renderer = await withPointerCallback<TRenderer>((cb) => Engine_createRendererJobThread(engine, cb));
      final manager = RenderManager_create(engine, renderer);
      RenderManager_attachToJobThread(manager);
      RenderManager_setPaused(manager, true);
      final view = await withPointerCallback<TView>((cb) => Engine_createViewJobThread(engine, cb));
      final name = 'worker-$round'.toNativeUtf8().cast<Char>();
      await withVoidCallback((id, cb) => View_setNameJobThread(view, name, id, cb));
      free(name);
      // The result owns its text. Renaming the view before callback delivery
      // must not change it.
      final pendingName = readName(view);
      final replacement = 'renamed-worker-$round'.toNativeUtf8().cast<Char>();
      await withVoidCallback((id, cb) => View_setNameJobThread(view, replacement, id, cb));
      free(replacement);
      final returnedName = await pendingName;
      if (returnedName != 'worker-$round') throw StateError('Invalid string callback: $returnedName');
      final disposableView = await withPointerCallback<TView>((cb) => Engine_createViewJobThread(engine, cb));
      final disposableName = 'deleted-view-Ω🚗'.toNativeUtf8().cast<Char>();
      await withVoidCallback((id, cb) => View_setNameJobThread(disposableView, disposableName, id, cb));
      free(disposableName);
      final beforeDestroy = readName(disposableView);
      await withVoidCallback((id, cb) => Engine_destroyViewJobThread(engine, disposableView, id, cb));
      if (await beforeDestroy != 'deleted-view-Ω🚗') throw StateError('View deletion invalidated its name callback');
      // Successful KTX creation and buffer release must also finish while
      // worker animation-frame callbacks are disabled.
      progress('engine $round KTX upload');
      final bytes = (await http.get(Uri.base.resolve('texture.ktx'))).bodyBytes;
      final bundle = Ktx1Bundle_create(bytes.address, bytes.length);
      late Future<Pointer<TTexture>> created;
      final released = withVoidCallback((id, releasedCallback) {
        created = withPointerCallback<TTexture>((createdCallback) {
          Ktx1Reader_createTextureJobThread(engine, bundle, id, releasedCallback, createdCallback);
        });
      });
      final texture = await created;
      await released.timeout(const Duration(seconds: 5));
      Ktx1Bundle_destroy(bundle);
      bytes.free();
      if (texture == nullptr) throw StateError('KTX creation failed');
      await withVoidCallback((id, cb) => Engine_destroyTextureJobThread(engine, texture, id, cb));
      progress('engine $round command burst');
      await Future.wait(
        List.generate(
          200,
          (_) => withVoidCallback((id, cb) {
            Engine_executeJobThread(engine, id, cb);
          }),
        ),
      );
      await withVoidCallback((id, cb) => Engine_destroyViewJobThread(engine, view, id, cb));
      await withVoidCallback((id, cb) => RenderManager_destroyJobThread(manager, id, cb));
      await withVoidCallback((id, cb) => Engine_destroyRendererJobThread(engine, renderer, id, cb));
      await withVoidCallback((id, cb) => Engine_destroyJobThread(engine, id, cb));
      JobThread_destroy(worker);
    }
    progress('viewer creation');
    await FFIFilamentApp.create(
      canvasSelector: '#test_canvas_3',
      config: FFIFilamentConfig(
        backend: Backend.OPENGL,
        loadResource: (path) async {
          final response = await http.get(Uri.base.resolve(path));
          if (response.statusCode != 200) throw StateError('Resource load failed');
          return response.bodyBytes;
        },
      ),
    );
    final app = FilamentApp.instance! as FFIFilamentApp;
    final viewer = ThermionViewerFFI(app: app);
    await viewer.initialized;
    final debugName = List.filled(32, 'viewer-name-').join();
    await (viewer.view as FFIView).setName(debugName);
    if (await viewer.view.getName() != debugName) {
      throw StateError('Public view name was not copied during callback delivery');
    }
    final camera = await viewer.getActiveCamera();
    await camera.lookAt(Vector3(2, 3, 4));
    final position = await camera.getPosition();
    if ((position - Vector3(2, 3, 4)).length > 1e-6) {
      throw StateError('Camera model matrix update failed');
    }
    var failed = false;
    try {
      await viewer.loadSkybox('missing.ktx');
    } on StateError {
      failed = true;
    }
    if (!failed) throw StateError('Missing skybox did not fail');
    progress('viewer skybox');
    await viewer.loadSkybox('skybox.ktx');
    progress('viewer IBL');
    await viewer.loadIbl('texture.ktx');
    progress('viewer disposal');
    await viewer.dispose();
    await app.destroy();
    globalContext['testResult'] =
        'PASS: full WASM module, callbacks, camera, uploads, viewer skybox/IBL, 4 engine lifecycles'.toJS;
  } catch (error, stack) {
    globalContext['testResult'] = 'FAIL: $error\n$stack'.toJS;
  }
}
