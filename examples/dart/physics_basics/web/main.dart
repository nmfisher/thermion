import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:physics_basics/physics_scene.dart';
import 'package:reactphysics3d_dart/reactphysics3d_dart.dart'
    show initializeReactPhysics3DWeb;
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart'
    hide NativeLibrary, Image_decode;
import 'package:web/web.dart';

const assetsDir = 'assets';

Future<void> main() async {
  try {
    await _boot();
  } catch (e, s) {
    final err = document.getElementById('error') as HTMLElement?;
    if (err != null) {
      err.textContent = '$e\n$s';
      err.style.display = 'block';
    }
  }
}

Future<void> _boot() async {
  Logger.root.onRecord.listen((record) => print(record));

  NativeLibrary.initBindings('thermion_dart');
  initializeReactPhysics3DWeb();

  final canvas =
      document.getElementById('thermion_canvas') as HTMLCanvasElement;
  final info = document.getElementById('info')!;
  final loading = document.getElementById('loading');
  final loadingText = document.getElementById('loading-text');

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

  var swapChain = await app.createHeadlessSwapChain(w0, h0);
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.view.setViewport(w0, h0);

  if (loadingText != null) {
    loadingText.textContent = 'Loading physics scene…';
  }
  final scene = await PhysicsScene.create(viewer, assetsDir: assetsDir);
  if (loadingText != null) {
    loadingText.textContent = 'Starting simulation…';
  }

  // Orbit camera around the center of the arena.
  final camera = await viewer.getActiveCamera();
  final target = Vector3(0, 1.5, 0);
  final up = Vector3(0, 1, 0);
  final cameraModel = await camera.getModelMatrix();
  final direction = cameraModel.getTranslation() - target;
  var radius = direction.length == 0 ? 16.0 : direction.length;
  var elevation = math.asin((direction.y / radius).clamp(-1.0, 1.0));
  var azimuth = math.atan2(direction.x, direction.z);
  const orbitSensitivity = 0.005;
  const scrollSensitivity = 0.01;
  final elevMax = math.pi / 2 - 0.05;

  void applyCamera() {
    final ce = math.cos(elevation);
    final dir = Vector3(
      ce * math.sin(azimuth),
      math.sin(elevation),
      ce * math.cos(azimuth),
    );
    final eye = target + dir * radius;
    camera.setModelMatrix(makeViewMatrix(eye, target, up)..invert());
  }

  var dragging = false;
  var lastX = 0.0;
  var lastY = 0.0;
  canvas.addEventListener(
    'pointerdown',
    (PointerEvent e) {
      dragging = true;
      lastX = e.clientX.toDouble();
      lastY = e.clientY.toDouble();
      canvas.setPointerCapture(e.pointerId);
    }.toJS,
  );
  canvas.addEventListener(
    'pointermove',
    (PointerEvent e) {
      if (!dragging) return;
      final x = e.clientX.toDouble();
      final y = e.clientY.toDouble();
      azimuth -= (x - lastX) * orbitSensitivity;
      elevation =
          (elevation - (y - lastY) * orbitSensitivity).clamp(-elevMax, elevMax);
      lastX = x;
      lastY = y;
      applyCamera();
    }.toJS,
  );
  canvas.addEventListener(
    'pointerup',
    (PointerEvent e) {
      dragging = false;
    }.toJS,
  );
  canvas.addEventListener(
    'wheel',
    (WheelEvent e) {
      e.preventDefault();
      radius = (radius + e.deltaY * scrollSensitivity).clamp(2.0, 50.0);
      applyCamera();
    }.toJS,
  );

  final resetBtn = document.getElementById('reset-btn');
  resetBtn?.addEventListener(
    'click',
    (Event _) {
      unawaited(scene.reset());
    }.toJS,
  );

  info.textContent = 'physics_basics — drag to orbit, scroll to zoom';

  Timer? resizeTimer;
  window.addEventListener(
    'resize',
    (Event _) {
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
          await camera.setLensProjection(
            near: await camera.getNear(),
            far: await camera.getCullingFar(),
            aspect: w / h,
            focalLength: await camera.getFocalLength(),
          );
        } catch (e) {
          print('resize failed: $e');
        }
      });
    }.toJS,
  );

  var firstFrame = true;
  num? lastTimestamp;
  late final JSFunction pump;
  Future<void> renderFrame(num timestamp) async {
    final dt = lastTimestamp == null ? 0.0 : (timestamp - lastTimestamp!) / 1000.0;
    lastTimestamp = timestamp;
    await scene.step(dt);
    await app.render();
    if (firstFrame) {
      firstFrame = false;
      loading?.setAttribute('hidden', '');
    }
    window.requestAnimationFrame(pump);
  }

  pump = ((num timestamp) {
    unawaited(
      renderFrame(timestamp).catchError((Object error, StackTrace stack) {
        final element = document.getElementById('error') as HTMLElement?;
        if (element != null) {
          element.textContent = '$error\n$stack';
          element.style.display = 'block';
        }
      }),
    );
  }).toJS;
  window.requestAnimationFrame(pump);
}
