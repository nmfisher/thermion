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
// This Dart side deliberately keeps the scene static and mirrors every piece
// of it into a plain JSON description (`window.thermionSidecarScene`), so the
// sidecar never has to guess transforms, materials, the camera or the hidden
// canvas Thermion renders into.
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

// One static scene, described once and used for both renderers.
final _cubeTransform = Matrix4.compose(
  Vector3(-0.7, 0.85, 0.0),
  Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 5),
  Vector3.all(0.85),
);
final _planeTransform = Matrix4.translation(Vector3(0, 0, 0));
final _cameraPosition = Vector3(3.0, 2.6, 4.6);
final _cameraFocus = Vector3(0, 0.7, 0);
final _sunDirection = Vector3(-0.6, -1.0, -0.4)..normalize();
const _sunIntensityLux = 40000.0;
const _skyColor = [0.35, 0.45, 0.60];
const _cubeBaseColor = [0.85, 0.30, 0.20];
const _planeBaseColor = [0.75, 0.75, 0.72];
const _fovDegrees = 45.0;

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
    'camera': {
      'transform': _mat4ToList(
          (makeViewMatrix(_cameraPosition, _cameraFocus, Vector3(0, 1, 0))
            ..invert())),
      'fovDegrees': _fovDegrees,
      'near': 0.1,
      'far': 100.0,
    },
  };
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
  await camera.lookAt(_cameraPosition, focus: _cameraFocus);
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

  final scene = await _describeScene();
  final bridge = {
    'offscreenCanvasSelector': offscreenSelector,
    'presentCanvasSelector': canvasSelector,
    'width': canvas.width,
    'height': canvas.height,
    'scene': scene,
  };
  web.window.setProperty(
      'thermionSidecarScene'.toJS, jsonEncode(bridge).toJS);

  // Drive Thermion frames. Each app.render() renders synchronously into the
  // hidden canvas on this (main-thread) engine; the sidecar reads that canvas
  // via its own rAF callback, registered after this one.
  void pump(num timestamp) {
    app.render();
    web.window.requestAnimationFrame(pump.toJS);
  }

  web.window.requestAnimationFrame(pump.toJS);

  // Notify the sidecar that the device + scene description are ready.
  web.window.callMethod('dispatchEvent'.toJS,
      web.Event('thermion-sidecar-ready'));
}

void _fail(String message) {
  final status = web.document.getElementById('status');
  if (status != null) status.textContent = message;
  throw StateError(message);
}
