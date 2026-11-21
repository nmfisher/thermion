import 'dart:async';
import 'dart:js_interop';

import 'package:logging/logging.dart';
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart'
    hide NativeLibrary, Image_decode;
import 'package:web/web.dart';

/// Default shader shown in the editor — a normal-debugging look that still
/// runs through the full lighting pipeline. Material shaders have no built-in
/// time uniform; animate via parameters if needed.
const defaultSource = '''
void material(inout MaterialInputs material) {
    prepareMaterial(material);

    // Base color from view-space normal — a cheap "normal debugging" look
    // that still exercises lighting plumbing.
    vec3 n = normalize(shading_normal);
    material.baseColor.rgb = 0.5 + 0.5 * n;
    material.roughness = 0.35;
    material.metallic = 0.0;
}
''';

const _meshes = <String, Geometry Function()>{
  'sphere': GeometryUtils.sphere,
  'cube': GeometryUtils.cube,
  'cylinder': GeometryUtils.cylinder,
  'cone': GeometryUtils.conic,
  'plane': GeometryUtils.plane,
};

Future<void> main() async {
  // Surface failures into the DOM (headless verification reads this).
  try {
    await _boot();
  } catch (e, s) {
    final err = document.getElementById('error');
    if (err != null) {
      err.textContent = '$e\n$s';
      (err as HTMLElement).style.display = 'block';
    }
  }
}

Future<void> _boot() async {
  Logger.root.onRecord.listen((record) => print(record));

  final loading = document.getElementById('loading') as HTMLElement?;
  void loadingText(String t) {
    (document.getElementById('loading-text') as HTMLElement).textContent = t;
  }

  // index.html awaits the Emscripten module onto window.thermion_dart first.
  NativeLibrary.initBindings('thermion_dart');

  final canvas =
      document.getElementById('thermion_canvas') as HTMLCanvasElement;
  canvas.width = canvas.clientWidth;
  canvas.height = canvas.clientHeight;

  await FFIFilamentApp.create(
    config: FFIFilamentConfig(backend: Backend.OPENGL),
  );
  final app = FilamentApp.instance! as FFIFilamentApp;

  if (!app.runtimeMaterialsSupported) {
    throw StateError(
      'This page needs the runtime-materials engine variant. Rebuild with '
      'runtime_materials: true in pubspec.yaml user defines (the example '
      'pubspec sets it) so the build hook fetches the filamat-enabled wasm.',
    );
  }

  final viewer = ThermionViewerFFI(app: app);
  await viewer.initialized;

  final w = canvas.clientWidth;
  final h = canvas.clientHeight;
  var swapChain = await app.createHeadlessSwapChain(w, h);
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.view.setViewport(w, h);

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: w / h,
    focalLength: 28.0,
  );

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -0.6)));

  loadingText('Compiling initial material…');

  // Initial compile of the default source; also proves runtime materials are
  // live before the UI is wired up.
  var currentMaterial = await app.compileMaterialSource(
    'editor_default',
    defaultSource,
  );
  var currentInstance = await currentMaterial.createInstance();

  // The current mesh entity; switching meshes destroys and recreates it
  // (geometry creation is cheap; the compile path is the slow part).
  var currentMesh = 'sphere';
  ThermionAsset meshEntity = await viewer.createGeometry(
    GeometryUtils.sphere(),
  );
  await _applyToAll(meshEntity, currentInstance);
  await camera.lookAt(Vector3(0, 0.4, 2.2), focus: Vector3(0, 0, 0));

  // ---- live compile loop ------------------------------------------------>

  final editor = document.getElementById('editor') as HTMLTextAreaElement;
  final status = document.getElementById('status') as HTMLElement;
  final shadingSelect =
      document.getElementById('shading-select') as HTMLSelectElement;
  final meshSelect =
      document.getElementById('mesh-select') as HTMLSelectElement;
  final compileBtn =
      document.getElementById('compile-btn') as HTMLButtonElement;
  final resetBtn = document.getElementById('reset-btn') as HTMLButtonElement;

  editor.value = defaultSource;

  void setStatus(String text, {String cls = ''}) {
    status.textContent = text;
    status.className = cls;
    editor.className = cls == 'err' ? 'err' : '';
  }

  // Serialize compiles: the native compile is synchronous on the job thread,
  // so a new request while one is in flight must wait (or drop). `compile` is
  // a stored closure because it and the debounce scheduler reference each
  // other.
  var compiling = false;
  var pending = false;
  Timer? debounce;
  late final Future<void> Function(String source, String shading) compile;

  void scheduleCompile() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 600), () {
      compile(editor.value, shadingSelect.value);
    });
  }

  MaterialShading _shadingFromName(String name) => switch (name) {
        'unlit' => MaterialShading.unlit,
        'subsurface' => MaterialShading.subsurface,
        'cloth' => MaterialShading.cloth,
        'specularGlossiness' => MaterialShading.specularGlossiness,
        _ => MaterialShading.lit,
      };

  Future<void> _compile(String source, String shading) async {
    if (compiling) {
      pending = true;
      return;
    }
    compiling = true;
    setStatus('Compiling…', cls: 'busy');
    final sw = Stopwatch()..start();
    try {
      final material = await app.compileMaterialSource(
        'editor_material',
        source,
        shading: _shadingFromName(shading),
      );
      final instance = await material.createInstance();
      await _applyToAll(meshEntity, instance);

      // Swap, then release the previous material/instance.
      final oldMaterial = currentMaterial;
      final oldInstance = currentInstance;
      currentMaterial = material;
      currentInstance = instance;

      await oldInstance.destroy();
      await oldMaterial.destroy();

      setStatus('Compiled in ${sw.elapsedMilliseconds} ms ($shading).',
          cls: 'ok');
    } catch (e) {
      setStatus('Compile failed:\n$e', cls: 'err');
    } finally {
      compiling = false;
      if (pending) {
        pending = false;
        scheduleCompile();
      }
    }
  }

  compile = _compile;

  editor.addEventListener(
    'input',
    (Event _) {
      scheduleCompile();
    }.toJS,
  );
  editor.addEventListener(
    'keydown',
    (KeyboardEvent e) {
      // Ctrl/Cmd+Enter compiles immediately (skips the debounce).
      if (e.key == 'Enter' && (e.ctrlKey || e.metaKey)) {
        e.preventDefault();
        debounce?.cancel();
        compile(editor.value, shadingSelect.value);
      }
    }.toJS,
  );
  compileBtn.addEventListener(
    'click',
    (Event _) {
      debounce?.cancel();
      compile(editor.value, shadingSelect.value);
    }.toJS,
  );
  resetBtn.addEventListener(
    'click',
    (Event _) {
      editor.value = defaultSource;
      shadingSelect.value = 'lit';
      compile(defaultSource, 'lit');
    }.toJS,
  );
  shadingSelect.addEventListener(
    'change',
    (Event _) {
      scheduleCompile();
    }.toJS,
  );
  meshSelect.addEventListener(
    'change',
    (Event _) {
      // The outer closure must stay synchronous: .toJS cannot convert a
      // function returning Future. Push the async work onto the event loop.
      Future(() async {
        final next = meshSelect.value;
        final factory = _meshes[next];
        if (next == currentMesh || factory == null) return;
        currentMesh = next;
        // Recreate the mesh at the same place; the current material instance
        // is applied to the new geometry.
        await viewer.destroyAsset(meshEntity);
        meshEntity = await viewer.createGeometry(factory());
        await _applyToAll(meshEntity, currentInstance);
      });
    }.toJS,
  );

  // ---- resize + render loop -------------------------------------------->

  Timer? resizeTimer;
  window.addEventListener(
    'resize',
    (Event _) {
      resizeTimer?.cancel();
      resizeTimer = Timer(const Duration(milliseconds: 150), () async {
        try {
          final cw = canvas.clientWidth;
          final chh = canvas.clientHeight;
          if (cw == 0 || chh == 0) return;
          await app.renderManager.detach(viewer.view);
          await app.destroySwapChain(swapChain);
          swapChain = await app.createHeadlessSwapChain(cw, chh);
          await app.renderManager.attach(viewer.view, swapChain);
          await viewer.view.setViewport(cw, chh);
          await camera.setLensProjection(
            near: 0.1,
            far: 100.0,
            aspect: cw / chh,
            focalLength: 28.0,
          );
        } catch (e) {
          print('resize failed: $e');
        }
      });
    }.toJS,
  );

  var firstFrame = true;
  void pump(num _) {
    app.render();
    if (firstFrame) {
      firstFrame = false;
      loading?.setAttribute('hidden', '');
    }
    window.requestAnimationFrame(pump.toJS);
  }

  loadingText('Starting render loop…');
  window.requestAnimationFrame(pump.toJS);
}

Future<void> _applyToAll(
    ThermionAsset entity, MaterialInstance instance) async {
  await entity.setMaterialInstanceForAll(instance);
}
