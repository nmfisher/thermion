import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart' hide NativeLibrary, Image_decode;
import 'package:thermion_examples_lib/examples_lib.dart';
import 'package:web/web.dart';

import 'web_input_handler.dart';

/// Assets are served at a relative `assets/` path on web (the default web
/// resource loader fetches them over HTTP).
const assetsDir = "assets";

Future<void> main() async {
  // Surface any failure into the DOM so headless verification can read it
  // (headless Chrome does not surface page console.log on stderr).
  try {
    await _boot();
  } catch (e, s) {
    final err = document.getElementById('error');
    if (err != null) {
      err.textContent = '$e\n$s';
    }
  }
}

/// Build the example-selector dropdown from the registry. Selecting an entry
/// reloads the page with `?example=<name>`.
void _buildSelector(String current) {
  final select =
      document.getElementById("example-select") as HTMLSelectElement;
  for (final name in galleryScenes.keys) {
    final opt = HTMLOptionElement();
    opt.value = name;
    opt.textContent = name;
    opt.selected = (name == current);
    select.appendChild(opt);
  }
  select.addEventListener('change', (Event _) {
    final uri = Uri.parse(window.location.href);
    final q = Map<String, String>.from(uri.queryParameters)
      ..['example'] = select.value;
    window.location.assign(uri.replace(queryParameters: q).toString());
  }.toJS);
}

Future<void> _boot() async {
  Logger.root.onRecord.listen((record) => print(record));

  // Load the Emscripten module that index.html placed on window.thermion_dart.
  NativeLibrary.initBindings("thermion_dart");

  final canvas = document.getElementById("thermion_canvas") as HTMLCanvasElement;

  // ?example=NAME selects the scene; default to basics.
  final exampleName = Uri.base.queryParameters['example'] ?? 'basics';
  final setup = galleryScenes[exampleName];
  final info = document.getElementById("info")!;

  // Populate the example-selector dropdown from the gallery scenes so it stays
  // in sync with the available examples. Changing it reloads with the new
  // ?example= value (a full reload is the only reliable way to switch scenes,
  // since the viewer exposes no scene-clear primitive).
  _buildSelector(exampleName);

  if (setup == null) {
    info.textContent =
        "Unknown example '$exampleName'. Available: ${galleryScenes.keys.join(', ')}";
    return;
  }

  // The canvas element is transferred to the worker (transferControlToOffscreen)
  // when Filament creates its GL context, so its backing size can't be set via
  // canvas.width after that. The native emscripten resize API is the only way
  // to size a transferred OffscreenCanvas, and it works both before and after
  // the transfer — so we use it everywhere, syncing to the CSS size x DPR.
  // Sync the canvas backing store to its CSS size BEFORE the engine creates
  // its GL context. Once Filament transfers the canvas to the worker
  // (transferControlToOffscreen) the backing store can't be resized from
  // here, so this must happen first. The same dimensions are used for the
  // swapchain + viewport so the scene isn't drawn off-canvas.
  final w0 = canvas.clientWidth;
  final h0 = canvas.clientHeight;
  canvas.width = w0;
  canvas.height = h0;

  await FFIFilamentApp.create(
    config: FFIFilamentConfig(backend: Backend.OPENGL),
  );
  final app = FilamentApp.instance! as FFIFilamentApp;

  final viewer = ThermionViewerFFI(app: app);
  await viewer.initialized;

  // A headless swapchain's backing size is fixed at creation, so resizing the
  // browser means rebuilding it. Track the current swapchain and rebuild it
  // (detach -> destroy -> create -> attach -> viewport) on resize.
  var swapChain = await app.createHeadlessSwapChain(w0, h0);
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.view.setViewport(w0, h0);

  await setup(viewer, assetsDir: assetsDir);

  // The example setups hardcode a square (1.0) projection aspect, which
  // stretches the scene on a non-square canvas. Re-apply each example's chosen
  // lens (near/far/focal) with the real viewport aspect so geometry isn't
  // distorted.
  final camera = await viewer.getActiveCamera();
  await _syncAspect(camera, w0, h0);

  // Orbit camera: drag to orbit a target (the origin, where transformToUnitCube
  // places every scene), scroll to dolly. The camera is updated on every
  // pointer event (per-event, not per-frame) so motion is continuous -- batching
  // per frame used to quantize the orbit because pointer events and frames
  // aren't phase-locked.
  final target = Vector3.zero();
  final up = Vector3(0, 1, 0);
  final camPos = (await camera.getModelMatrix()).getTranslation();
  final r0 = camPos.length == 0 ? 1.0 : camPos.length;
  var radius = r0;
  var elevation = math.asin((camPos.y / r0).clamp(-1.0, 1.0));
  var azimuth = math.atan2(camPos.x, camPos.z);
  const orbitSensitivity = 0.005;
  const scrollSensitivity = 0.01;
  final elevMax = math.pi / 2 - 0.05;

  void applyCamera() {
    final ce = math.cos(elevation);
    final eye = target +
        Vector3(
              ce * math.sin(azimuth),
              math.sin(elevation),
              ce * math.cos(azimuth),
            ) *
            radius;
    camera.setModelMatrix(makeViewMatrix(eye, target, up)..invert());
  }

  WebInputHandler(
    canvas: canvas,
    onDrag: (dx, dy) {
      azimuth -= dx * orbitSensitivity;
      elevation = (elevation - dy * orbitSensitivity).clamp(-elevMax, elevMax);
      applyCamera();
    },
    onScroll: (s) {
      radius = (radius + s * scrollSensitivity).clamp(1.0, 50.0);
      applyCamera();
    },
  );

  info.textContent = "$exampleName — drag to orbit, scroll to zoom";

  // Debounced resize: rebuild the swapchain at the new canvas size and re-sync
  // the projection aspect so the scene keeps its proportions.
  Timer? resizeTimer;
  window.addEventListener('resize', (Event _) {
    resizeTimer?.cancel();
    resizeTimer = Timer(const Duration(milliseconds: 150), () async {
      try {
        final w = canvas.clientWidth;
        final h = canvas.clientHeight;
        if (w == 0 || h == 0) return;
        await app.renderManager.detach(viewer.view);
        await app.destroySwapChain(swapChain);
        swapChain = await app.createHeadlessSwapChain(w, h);
        await app.renderManager.attach(viewer.view, swapChain);
        await viewer.view.setViewport(w, h);
        await _syncAspect(camera, w, h);
      } catch (e) {
        // Resize failures must not kill the render loop.
        print('resize failed: $e');
      }
    });
  }.toJS);

  // On web FILAMENT_SINGLE_THREADED is true: render() is fire-and-forget and
  // the C++ worker drives the actual rAF loop. Its RenderManager tick advances
  // animations using the worker's absolute monotonic frame time, so this pump
  // only requests a render. Updating the animation manager here with a Dart
  // frame delta would mix clock domains and repeatedly reset the pose.
  void pump(num _) {
    app.render();
    window.requestAnimationFrame(pump.toJS);
  }

  window.requestAnimationFrame(pump.toJS);
}

/// Re-apply the camera's current lens with the real viewport aspect, so the
/// scene isn't stretched on non-square canvases.
Future<void> _syncAspect(Camera camera, int w, int h) async {
  final aspect = w / h;
  final near = await camera.getNear();
  final far = await camera.getCullingFar();
  final focal = await camera.getFocalLength();
  await camera.setLensProjection(
    near: near,
    far: far,
    aspect: aspect,
    focalLength: focal,
  );
}
