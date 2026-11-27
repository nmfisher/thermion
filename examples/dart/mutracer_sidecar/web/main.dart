// MuTracer sidecar spike (shared-device rendering).
//
// Thermion renders a small static scene with the WebGPU backend into an
// offscreen (present-skip) swapchain, then exports its browser GPUDevice to
// JavaScript (Module['thermionWebGPUDevice']). The JS sidecar
// (mutracer_sidecar.js) imports that device, mirrors the scene into
// @meimu/mutracer, path-traces frames on the SAME device and composites its
// image over Thermion's offscreen output before presenting.
//
// Both the swapchain and the device export come from the web-only extension
// in package:thermion_dart/thermion_dart_web.dart (PR #521):
// createOffscreenSwapChain(), webGPUDevice and offscreenCanvasSelector().
//
// This Dart side deliberately keeps the geometry static and mirrors it into a
// plain JSON description (`window.thermionSidecarScene`) ONCE, so the sidecar
// never has to guess transforms or materials. Everything that changes per
// frame goes through two small per-frame channels instead:
//
//   window.thermionSidecarCamera  { viewMatrix, position, focus, revision }
//       published EVERY frame; `revision` only increments when the camera
//       actually moved (the sidecar keys its accumulation reset on it).
//   window.thermionSidecarMode    'raytrace' | 'viewport'
//       written whenever the user toggles the mode (R key or button).
//
// Camera: an orbit camera (drag = orbit around the focus point, wheel =
// dolly) drives the Thermion camera, and the very same view matrix is pushed
// to the sidecar so both renderers stay in sync.
//
// Screenshot capture (C key / Capture button) is mode-aware behind one API,
// `capture()`: in raytrace mode the sidecar reads back the frame it presents
// (`window.thermionSidecarCapture`, a WebGPU readback of the visible canvas'
// swapchain texture — Thermion's capture API cannot see MuTracer's textures);
// in viewport mode Thermion's own `app.capture()` reads the raster frame the
// sidecar passes through. Both return RGBA8, top-left origin; the result is
// encoded as PNG and downloaded.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart'
    hide NativeLibrary, Image_decode;
import 'package:thermion_dart/thermion_dart_web.dart';
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart'
    as web_bindings show NativeLibrary;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:web/web.dart' as web;

/// Selector of the canvas the sidecar presents the composited image to.
/// Thermion never presents here: its swapchain is offscreen (present-skip),
/// so its frames land on the hidden canvas the engine reports through
/// `app.offscreenCanvasSelector` instead (published to the sidecar below).
const canvasSelector = '#thermion_canvas';

/// Presentation modes understood by the sidecar.
enum RenderMode {
  /// Path-trace on the shared device and composite over Thermion's frame.
  raytrace,

  /// Present Thermion's offscreen raster frame unchanged (no path tracing).
  viewport,
}

extension on RenderMode {
  String get name => this == RenderMode.raytrace ? 'raytrace' : 'viewport';
  RenderMode get other =>
      this == RenderMode.raytrace ? RenderMode.viewport : RenderMode.raytrace;
}

// One static scene, described once and used for both renderers.
final _cubeTransform = Matrix4.compose(
  Vector3(-0.7, 0.85, 0.0),
  Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 5),
  Vector3.all(0.85),
);
final _planeTransform = Matrix4.translation(Vector3(0, 0, 0));
final _cameraPosition = Vector3(3.0, 2.6, 4.6);
final _cameraFocus = Vector3(0, 0.7, 0);
final _up = Vector3(0, 1, 0);
final _sunDirection = Vector3(-0.6, -1.0, -0.4)..normalize();
const _sunIntensityLux = 40000.0;
const _skyColor = [0.35, 0.45, 0.60];
const _cubeBaseColor = [0.85, 0.30, 0.20];
const _planeBaseColor = [0.75, 0.75, 0.72];
const _fovDegrees = 45.0;

// Orbit camera tuning.
const _orbitRadiansPerPixel = 0.005;
const _pitchLimit = 1.5; // ~86 degrees; keeps the up vector meaningful.
const _minDistance = 1.5;
const _maxDistance = 30.0;
const _dollyScalePerWheelPixel = 1.001; // ~10% per 100-unit wheel notch.

const _controlsHint = 'drag=orbit · wheel=zoom · R=toggle · C=capture';

double _clampDouble(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);

/// PointerEvent clientX/clientY as doubles, read through JS interop.
///
/// package:web types these getters as `int`, but browsers deliver FRACTIONAL
/// coordinates (trackpads, high-DPI or zoomed displays). Under dart2wasm the
/// int-typed getter converts the JS number at the boundary and THROWS on any
/// non-integral value, so the typed getter is unusable here. Reading the
/// property as a JS number keeps the fraction. (`pointerId` really is an
/// integer, so it stays typed.)
(double, double) _clientCoords(web.PointerEvent e) => (
      (e as JSObject).getProperty<JSNumber>('clientX'.toJS).toDartDouble,
      (e as JSObject).getProperty<JSNumber>('clientY'.toJS).toDartDouble,
    );

/// Orbit camera state around a focus point, held as spherical coordinates so
/// that drags are increments and the camera never drifts or flips.
class _OrbitState {
  _OrbitState({
    required this.focus,
    required this.distance,
    required this.yaw,
    required this.pitch,
  });

  /// Derives the spherical coordinates of an existing position/focus pair.
  factory _OrbitState.fromPosition(Vector3 position, Vector3 focus) {
    final offset = position - focus;
    final distance = offset.length;
    return _OrbitState(
      focus: focus.clone(),
      distance: distance,
      yaw: math.atan2(offset.x, offset.z),
      pitch: math.asin(_clampDouble(offset.y / distance, -1.0, 1.0)),
    );
  }

  final Vector3 focus;
  double distance;
  double yaw; // azimuth around +Y, 0 = looking down -Z from +Z
  double pitch; // elevation above the XZ plane

  Vector3 get position => Vector3(
        focus.x + distance * math.cos(pitch) * math.sin(yaw),
        focus.y + distance * math.sin(pitch),
        focus.z + distance * math.cos(pitch) * math.cos(yaw),
      );

  Matrix4 get viewMatrix => makeViewMatrix(position, focus, _up);

  /// Applies a drag of [dx], [dy] CSS pixels: yaw follows the pointer
  /// horizontally, pitch follows it vertically (clamped).
  void orbit(double dx, double dy) {
    yaw -= dx * _orbitRadiansPerPixel;
    pitch = _clampDouble(pitch - dy * _orbitRadiansPerPixel, -_pitchLimit, _pitchLimit);
  }

  /// Applies a wheel delta in pixels: positive = dolly out.
  void dolly(double deltaY) {
    distance = _clampDouble(
        distance * math.pow(_dollyScalePerWheelPixel, deltaY).toDouble(),
        _minDistance,
        _maxDistance);
  }
}

List<double> _mat4ToList(Matrix4 m) =>
    List<double>.generate(16, (i) => m.storage[i]);

Future<Map<String, Object?>> _describeScene() async {
  return {
    'meshes': [
      {
        'name': 'cube',
        'geometry': 'unitCube', // GeometryUtils.cube(): -1..1 on each axis
        'transform': _mat4ToList(_cubeTransform),
        'baseColor': _cubeBaseColor,
        'metallic': 0.0,
        'roughness': 0.35,
      },
      {
        'name': 'ground',
        'geometry': 'plane12', // GeometryUtils.plane(12, 12): XZ, +Y normal
        'transform': _mat4ToList(_planeTransform),
        'baseColor': _planeBaseColor,
        'metallic': 0.0,
        'roughness': 0.8,
      },
    ],
    'sun': {
      'direction': [_sunDirection.x, _sunDirection.y, _sunDirection.z],
      // Filament lux -> MuTracer irradiance on a facing surface (approximate;
      // the sidecar composites its own shading over Thermion's, so exact
      // photometric parity is not the point of the spike).
      'intensity': _sunIntensityLux / 683.0 * 0.1,
      'color': [1.0, 1.0, 1.0],
    },
    'background': [..._skyColor, 1.0],
    // Initial camera only: live camera updates arrive per frame through
    // `window.thermionSidecarCamera` (see _publishCamera).
    'camera': {
      'transform': _mat4ToList(makeViewMatrix(
        _cameraPosition,
        _cameraFocus,
        _up,
      )..invert()),
      'fovDegrees': _fovDegrees,
      'near': 0.1,
      'far': 100.0,
    },
  };
}

/// Initial mode may be forced with `?mode=raytrace|viewport` (handy for
/// headless checks); the default is the path-traced composite.
RenderMode _initialMode() {
  final query = web.window.location.search;
  final params = Uri.splitQueryString(query.startsWith('?') ? query.substring(1) : query);
  return params['mode'] == 'viewport' ? RenderMode.viewport : RenderMode.raytrace;
}

Future<void> main() async {
  Logger.root.onRecord.listen(print);

  if (!(web.window.navigator as JSObject).has('gpu')) {
    _fail('This example needs WebGPU (navigator.gpu is unavailable).');
    return;
  }

  // Must precede the thermion_dart_web extension calls: it probes the loaded
  // module for the engine's offscreen entry point (supportsSkipPresent).
  web_bindings.NativeLibrary.initBindings('thermion_dart');

  final canvas =
      web.document.querySelector(canvasSelector) as web.HTMLCanvasElement;
  canvas.width = canvas.clientWidth;
  canvas.height = canvas.clientHeight;

  await FFIFilamentApp.create(
    config: FFIFilamentConfig(backend: Backend.WEBGPU),
    canvasSelector: canvasSelector,
  );
  final app = FilamentApp.instance! as FFIFilamentApp;

  // Offscreen (present-skip) swapchain: Thermion renders into the hidden
  // canvas the engine owns; the JS sidecar composites and presents. There is
  // no skipPresent flag and no window handle: offscreen-ness is the entry
  // point itself (Thermion_createOffscreenSwapChain, WebGPU engines only;
  // throws UnsupportedError elsewhere).
  final swapChain = await app.createOffscreenSwapChain();

  // Ask the engine which hidden canvas that swapchain renders into (it is
  // derived from this engine's viewer canvas and created on first use), and
  // publish it so the sidecar reads the very same canvas rather than
  // reconstructing the id.
  final offscreenSelector = app.offscreenCanvasSelector;
  if (offscreenSelector == null) {
    _fail('Engine did not provide an offscreen canvas selector.');
    return;
  }
  Logger('mutracer_sidecar').info(
      'Created offscreen (present-skip) swapchain rendering into '
      '$offscreenSelector');

  final viewer = ThermionViewerFFI(app: app);
  await viewer.initialized;
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.setViewport(canvas.width, canvas.height);
  await viewer.setRendering(true);
  // No tone mapping / bloom on the Thermion side: the sidecar composites the
  // raw offscreen image, so keep post-processing out of the comparison.
  await viewer.setPostProcessing(false);

  final camera = await viewer.getActiveCamera();
  await camera.setProjectionFromVerticalFieldOfView(
      _fovDegrees, 0.1, 100.0, canvas.width / canvas.height);
  final orbit = _OrbitState.fromPosition(_cameraPosition, _cameraFocus);
  await camera.lookAt(orbit.position, focus: orbit.focus);
  await camera.setExposure(16.0, 1 / 125.0, 100.0);

  // Static scene: sky color + sun + two ubershader meshes.
  await (await viewer.view.getScene()).setSkybox(
    await app.createColoredSkybox(
        r: _skyColor[0], g: _skyColor[1], b: _skyColor[2], a: 1.0),
  );
  await viewer.addDirectLight(DirectLight.sun(
    direction: _sunDirection.clone(),
    intensity: _sunIntensityLux,
    castShadows: true,
  ));
  await viewer.setShadowsEnabled(true);

  final cubeMaterial = await app.createUbershaderMaterial();
  await cubeMaterial.setBaseColorFactor(
      _cubeBaseColor[0], _cubeBaseColor[1], _cubeBaseColor[2], 1.0);
  await cubeMaterial.setMetallicFactor(0.0);
  await cubeMaterial.setRoughnessFactor(0.35);
  final cube = await viewer.createGeometry(GeometryUtils.cube(),
      materialInstances: [cubeMaterial.materialInstance]);
  await cube.setTransform(_cubeTransform);

  final planeMaterial = await app.createUbershaderMaterial();
  await planeMaterial.setBaseColorFactor(
      _planeBaseColor[0], _planeBaseColor[1], _planeBaseColor[2], 1.0);
  await planeMaterial.setMetallicFactor(0.0);
  await planeMaterial.setRoughnessFactor(0.8);
  final plane = await viewer.createGeometry(
      GeometryUtils.plane(width: 12, height: 12),
      materialInstances: [planeMaterial.materialInstance]);
  await plane.setTransform(_planeTransform);

  // Export the engine's GPUDevice (Module['thermionWebGPUDevice']) and hand
  // the sidecar everything it needs. The sidecar imports the JS device
  // (WebGPU.importJsDevice-style: same GPUDevice object, caller-owned by the
  // sidecar engine) and renders on the same queues Thermion uses.
  final device = app.webGPUDevice;
  if (device == null) {
    _fail('Engine did not export a WebGPU device. Build the engine with '
        'THERMION_ENABLE_WEBGPU=ON (see README).');
    return;
  }

  // Geometry-only description, published once. Camera and mode are per-frame
  // channels (below), so the sidecar never has to re-read the scene.
  final bridge = {
    'offscreenCanvasSelector': offscreenSelector,
    'presentCanvasSelector': canvasSelector,
    'width': canvas.width,
    'height': canvas.height,
    'scene': await _describeScene(),
  };
  web.window.setProperty(
      'thermionSidecarScene'.toJS, jsonEncode(bridge).toJS);

  // --- Orbit camera + mode toggle -------------------------------------------

  // Camera edits from input; applied to the Thermion camera and published
  // to the sidecar on the next pump, so drags and frames never interleave.
  var cameraDirty = false;
  var cameraRevision = 0;

  var mode = _initialMode();

  final modeLabel = web.document.querySelector('#mode_label');
  final modeButton =
      web.document.querySelector('#mode_toggle') as web.HTMLButtonElement?;

  void publishMode() {
    web.window.setProperty('thermionSidecarMode'.toJS, mode.name.toJS);
    if (modeLabel != null) {
      modeLabel.textContent = 'mode: ${mode.name} · $_controlsHint';
    }
    if (modeButton != null) {
      modeButton.textContent = mode == RenderMode.raytrace
          ? 'Viewport (R)'
          : 'Raytrace (R)';
      modeButton.title = mode == RenderMode.raytrace
          ? 'Show Thermion\u2019s raster frame only (no path tracing)'
          : 'Path-trace on the shared device and composite';
    }
  }

  void toggleMode() {
    mode = mode.other;
    publishMode();
  }

  publishMode();

  modeButton?.addEventListener('click', ((web.Event _) {
    toggleMode();
    // Keep Space/Enter from re-triggering the button while orbiting.
    modeButton.blur();
  }).toJS);

  // --- Screenshot capture (mode-aware) ---------------------------------------

  // One Dart-facing API for both modes. Both paths return the SAME shape:
  // RGBA8, top-left origin, `canvas.width * canvas.height * 4` bytes.
  //
  //   raytrace: the sidecar reads back the frame it presents
  //     (`window.thermionSidecarCapture()`, js/mutracer_sidecar.js) in its
  //     frame loop, right after `display.present()`. While the camera moves
  //     this is the preview that is on screen. Thermion's `app.capture()` is
  //     a Filament `readPixels` on a Filament target and cannot see MuTracer's
  //     textures, so it is not an option here.
  //   viewport: Thermion's capture API on the offscreen swapchain
  //     (`app.capture(swapChain, pixelDataType: UBYTE)`), which is exactly
  //     the raster frame the sidecar passes through. Filament's WebGPU
  //     `readPixels` copies rows in texture order (row 0 = top), so the
  //     orientation matches the sidecar's and no flip is needed.
  //
  // The viewport capture begins a Filament frame of its own. Filament admits a
  // frame only once the previous one has signalled completion, and it learns
  // that from a poll it flushes on rejection — so the render pump (a frame
  // every animation frame) always gets admitted on its retry while a capture
  // arriving right behind it is rejected and, on a software adapter, fails
  // outright with "Failed to begin frame" (its 16 ms retries stay phase-locked
  // to the pump's frames). While a viewport capture is in flight the pump
  // therefore renders only every 4th frame (see [pump]): the sidecar keeps
  // presenting the last raster frame, so nothing visibly changes.
  //
  // Fallback: the readback of `app.capture()` is a GPU buffer map whose
  // callback the engine must pump to the Dart side, and on the Emscripten
  // (main-thread) WebGPU engine build this spike runs on it is never
  // delivered — the capture never completes (`Engine_flushAndWait` is no way
  // out either: its wait loop does not process events on Emscripten and hangs
  // the page). So a viewport capture waits a bounded time for Thermion's
  // result and otherwise reads back the PRESENTED frame from the sidecar — in
  // viewport mode that is the same raster frame, passed through unchanged.
  // The status line says which of the two produced the image.
  const thermionCaptureTimeout = Duration(seconds: 2);
  var captureHold = false;
  final _logger = Logger('mutracer_sidecar');

  /// The sidecar's readback of the frame it presents next (either mode).
  Future<Uint8List> _captureFromSidecar() async {
    if (!(web.window as JSObject).has('thermionSidecarCapture')) {
      throw StateError(
          'The sidecar capture API (window.thermionSidecarCapture) is missing: '
          'the sidecar did not start.');
    }
    final promise = web.window
        .callMethod<JSPromise<JSUint8Array>>('thermionSidecarCapture'.toJS);
    // Copy out of the JS buffer so the result does not alias the readback.
    return Uint8List.fromList((await promise.toDart).toDart);
  }

  /// Thermion's own readback of the offscreen swapchain (viewport mode).
  Future<Uint8List> _captureFromThermion() async {
    final captured = await app.capture(
      swapChain,
      view: viewer.view,
      pixelDataFormat: PixelDataFormat.RGBA,
      pixelDataType: PixelDataType.UBYTE,
    );
    if (captured.isEmpty) {
      throw StateError('Thermion capture returned no view.');
    }
    return captured.first.$2;
  }

  /// Captures the current frame as RGBA8 (see the comment above). Returns the
  /// pixels and the path that produced them, for the status line.
  Future<({Uint8List rgba, String source})> capture() async {
    if (mode == RenderMode.viewport) {
      final pending = _captureFromThermion();
      // A late result (or error) of an abandoned capture must not surface as
      // an unhandled asynchronous error.
      unawaited(pending.then<void>((_) {}, onError: (Object error) {
        _logger.warning('late Thermion capture result: $error');
      }));
      try {
        final rgba = await pending.timeout(thermionCaptureTimeout);
        return (rgba: rgba, source: 'Thermion app.capture()');
      } on Object catch (error) {
        _logger.warning(
            'Thermion capture did not complete ($error); reading the '
            'presented frame back through the sidecar instead.');
        return (rgba: await _captureFromSidecar(), source: 'sidecar readback');
      }
    }
    return (rgba: await _captureFromSidecar(), source: 'sidecar readback');
  }

  final captureButton =
      web.document.querySelector('#capture') as web.HTMLButtonElement?;
  final captureStatus = web.document.querySelector('#capture_status');
  var captureInFlight = false;

  void reportCapture(String text) {
    if (captureStatus != null) {
      captureStatus.textContent = text.isEmpty ? '' : ' · $text';
    }
  }

  void downloadPng(String name, Uint8List png) {
    final blob = web.Blob([png.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = name;
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    // The download starts inside click(); release the blob afterwards.
    unawaited(Future<void>.delayed(
        const Duration(seconds: 10), () => web.URL.revokeObjectURL(url)));
  }

  // Captures the current mode's frame, encodes it as PNG and downloads it as
  // `mutracer_<mode>_<WxH>_<timestamp>.png`. The button is disabled while a
  // capture is in flight (a readback takes a few frames; a viewport capture
  // may wait up to 2 s for Thermion's result).
  Future<void> saveCapture() async {
    if (captureInFlight) return;
    captureInFlight = true;
    if (captureButton != null) captureButton.disabled = true;
    final capturedMode = mode.name;
    reportCapture('capturing $capturedMode…');
    if (mode == RenderMode.viewport) captureHold = true;
    try {
      final (rgba: rgba, source: source) = await capture();
      final width = canvas.width;
      final height = rgba.length ~/ (width * 4);
      if (height <= 0 || rgba.length != width * height * 4) {
        throw StateError(
            'unexpected pixel buffer: ${rgba.length} bytes at width $width');
      }
      final png = await pixelBufferToPng(rgba, width, height,
          hasAlpha: true, isFloat: false);
      final name = 'mutracer_${capturedMode}_${width}x${height}_'
          '${DateTime.now().millisecondsSinceEpoch}.png';
      downloadPng(name, png);
      reportCapture('captured $capturedMode ${width}x${height} [$source] → '
          '${png.length} bytes PNG ($name)');
    } on Object catch (error) {
      _logger.severe('capture ($capturedMode) failed: $error');
      reportCapture('capture ($capturedMode) failed: $error');
    } finally {
      captureHold = false;
      captureInFlight = false;
      if (captureButton != null) captureButton.disabled = false;
    }
  }

  captureButton?.addEventListener('click', ((web.Event _) {
    // Keep Space/Enter from re-triggering the button while it is disabled.
    captureButton.blur();
    saveCapture();
  }).toJS);

  // R toggles the mode, C captures (both ignored with a modifier key held
  // and on key auto-repeat).
  web.document.addEventListener('keydown', ((web.KeyboardEvent e) {
    if (e.ctrlKey || e.metaKey || e.altKey || e.repeat) return;
    if (e.key == 'r' || e.key == 'R') {
      e.preventDefault();
      toggleMode();
    } else if (e.key == 'c' || e.key == 'C') {
      e.preventDefault();
      saveCapture();
    }
  }).toJS);

  // Pointer input on the visible canvas (the one the sidecar presents to);
  // Thermion's own canvas is hidden, so this is where the user looks.
  var dragging = false;
  var activePointer = -1;
  // Last pointer position in CSS pixels; fractional (see _clientCoords).
  var lastX = 0.0, lastY = 0.0;

  void onPointerDown(web.PointerEvent e) {
    if (dragging) return;
    dragging = true;
    activePointer = e.pointerId;
    final (x, y) = _clientCoords(e);
    lastX = x;
    lastY = y;
    // Keep receiving moves outside the canvas until the pointer is released.
    try {
      canvas.setPointerCapture(e.pointerId);
    } on Object catch (_) {
      // Capture is best-effort (synthetic events may not allow it).
    }
    e.preventDefault();
  }

  void onPointerMove(web.PointerEvent e) {
    if (!dragging || e.pointerId != activePointer) return;
    final (x, y) = _clientCoords(e);
    orbit.orbit(x - lastX, y - lastY);
    lastX = x;
    lastY = y;
    cameraDirty = true;
    e.preventDefault();
  }

  void onPointerEnd(web.PointerEvent e) {
    if (e.pointerId != activePointer) return;
    dragging = false;
    activePointer = -1;
  }

  canvas.addEventListener('pointerdown', onPointerDown.toJS);
  canvas.addEventListener('pointermove', onPointerMove.toJS);
  canvas.addEventListener('pointerup', onPointerEnd.toJS);
  canvas.addEventListener('pointercancel', onPointerEnd.toJS);
  canvas.addEventListener(
      'wheel',
      ((web.WheelEvent e) {
        e.preventDefault();
        orbit.dolly(e.deltaY);
        cameraDirty = true;
      }).toJS,
      web.AddEventListenerOptions(passive: false));

  // The per-frame camera channel object: the same JS object every frame,
  // mutated in place, so the sidecar can keep a reference and only compare
  // `revision`. `viewMatrix` is the column-major world->camera matrix
  // (makeViewMatrix); the sidecar inverts it into MuTracer's camera transform.
  final cameraChannel = JSObject();
  cameraChannel.setProperty('viewMatrix'.toJS, Float32List(16).toJS);
  cameraChannel.setProperty('revision'.toJS, 0.toJS);
  web.window.setProperty('thermionSidecarCamera'.toJS, cameraChannel);

  void publishCamera() {
    final view = orbit.viewMatrix;
    cameraChannel.setProperty(
        'viewMatrix'.toJS, Float32List.fromList(view.storage).toJS);
    final p = orbit.position;
    cameraChannel.setProperty(
        'position'.toJS, [p.x.toJS, p.y.toJS, p.z.toJS].toJS);
    cameraChannel.setProperty('focus'.toJS,
        [orbit.focus.x.toJS, orbit.focus.y.toJS, orbit.focus.z.toJS].toJS);
    cameraChannel.setProperty('revision'.toJS, cameraRevision.toJS);
  }

  // Drive Thermion frames. Each app.render() renders synchronously into the
  // hidden canvas on this (main-thread) engine; the sidecar reads that canvas
  // via its own rAF callback, registered after this one. The camera channel is
  // refreshed every frame BEFORE rendering, so the sidecar's frame (same
  // animation frame, later callback) always sees the matrix Thermion just
  // rendered with.
  var pumpFrame = 0;
  void pump(num timestamp) {
    pumpFrame++;
    if (cameraDirty) {
      cameraDirty = false;
      cameraRevision++;
      // Same spherical state for both renderers: Thermion via lookAt, the
      // sidecar via the view matrix published below.
      camera
          .lookAt(orbit.position, focus: orbit.focus)
          .catchError((Object error) {
        Logger('mutracer_sidecar').severe('camera.lookAt failed: $error');
      });
    }
    publishCamera();
    // Throttled to every 4th frame while a viewport capture is in flight
    // (see [captureHold]).
    if (!captureHold || pumpFrame % 4 == 0) app.render();
    web.window.requestAnimationFrame(pump.toJS);
  }

  web.window.requestAnimationFrame(pump.toJS);

  // Notify the sidecar that the device + scene description are ready.
  web.window.callMethod('dispatchEvent'.toJS,
      web.Event('thermion-sidecar-ready'));
}

void _fail(String message) {
  final status = web.document.getElementById('progress') ??
      web.document.getElementById('status');
  if (status != null) status.textContent = message;
  throw StateError(message);
}
