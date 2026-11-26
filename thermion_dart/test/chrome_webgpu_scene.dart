import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart' as web_bindings show NativeLibrary;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart_web.dart';
import 'package:web/web.dart' as web;

@JS('finishWebGpuCheck')
external void finishWebGpuCheck(JSBoolean passed, JSString message);

/// Samples the center pixel of [source] through a scratch 2D canvas.
///
/// Never call getContext('2d') on [source] itself: a canvas' context mode
/// is locked for its lifetime, so a WebGPU canvas returns null for '2d'.
/// drawImage copies the current contents, then getImageData reads them.
Uint8ClampedList _sampleCenter(web.HTMLCanvasElement scratch, web.HTMLCanvasElement source) {
  final context = scratch.getContext('2d') as web.CanvasRenderingContext2D;
  context.clearRect(0, 0, scratch.width, scratch.height);
  context.drawImage(source, 0, 0);
  return context.getImageData(source.width ~/ 2, source.height ~/ 2, 1, 1).data.toDart;
}

bool _isGreen(Uint8ClampedList pixel) => pixel[1] > 100 && pixel[0] < 40 && pixel[2] < 40 && pixel[3] > 200;

bool _isRed(Uint8ClampedList pixel) => pixel[0] > 100 && pixel[1] < 40 && pixel[2] < 40 && pixel[3] > 200;

/// Renders the (single, shared) cube into [swapChain] and waits until the
/// center pixel of [readCanvas] satisfies [matches]. [readCanvas] is the
/// visible canvas for a presenting swapchain, or the hidden offscreen
/// canvas for a present-skip one; pixels are read via [scratch].
Future<Uint8ClampedList> _renderCubeInto(
  FFIFilamentApp app,
  ThermionViewerFFI viewer,
  SwapChain swapChain,
  web.HTMLCanvasElement readCanvas,
  web.HTMLCanvasElement scratch,
  bool Function(Uint8ClampedList) matches,
  String expected,
  List<String> errors,
) async {
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.setRendering(true);
  await viewer.view.setViewport(readCanvas.width, readCanvas.height);

  late Uint8ClampedList pixel;
  for (var frame = 0; frame < 30; frame++) {
    await app.render();
    pixel = _sampleCenter(scratch, readCanvas);
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    if (matches(pixel)) return pixel;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('Expected a $expected center pixel. Got RGBA ${pixel.toList()}.');
}

Future<String> renderCube() async {
  final canvas = web.document.getElementById('thermion_canvas') as web.HTMLCanvasElement;
  // All pixel reads go through this scratch 2D canvas; the WebGPU canvases
  // are never asked for a 2D context.
  final scratch = web.HTMLCanvasElement()
    ..width = canvas.width
    ..height = canvas.height;

  final module = await (globalContext['__thermionReady'] as JSPromise<JSObject>).toDart;
  final errors = <String>[];
  final device = module['preinitializedWebGPUDevice'] as web.EventTarget?;
  if (device == null) throw StateError('Chrome did not create a WebGPU device.');
  device.addEventListener(
    'uncapturederror',
    ((web.Event event) {
      final error = (event as JSObject)['error'] as JSObject;
      errors.add((error['message'] as JSString).toDart);
    }).toJS,
  );

  web_bindings.NativeLibrary.initBindings('thermion_dart');
  await FFIFilamentApp.create(config: FFIFilamentConfig(backend: Backend.WEBGPU));
  final app = FilamentApp.instance! as FFIFilamentApp;
  final viewer = ThermionViewerFFI(app: app);
  await viewer.initialized;

  // The web-only extension exports the browser GPUDevice the engine runs
  // on; it must be the very object Chrome preinitialized the engine with
  // (strict JS equality — Dart wrappers are not comparable).
  final exportedDevice = app.webGPUDevice;
  if (exportedDevice == null) throw StateError('webGPUDevice is null on a WebGPU engine.');
  if (!(exportedDevice.jsObject as JSObject).strictEquals(device as JSObject).toDart) {
    throw StateError('webGPUDevice is not the preinitialized browser device.');
  }
  final moduleDevice = module['thermionWebGPUDevice'] as JSObject?;
  if (moduleDevice == null || !moduleDevice.strictEquals(device as JSObject).toDart) {
    throw StateError('Module.thermionWebGPUDevice is not the preinitialized device.');
  }

  // Default selector: the engine was created without a canvasSelector, so
  // the getter must resolve the engine's default canvas from its job thread.
  final offscreenSelector = app.offscreenCanvasSelector;
  if (offscreenSelector != '#thermion_canvas__thermion_offscreen') {
    throw StateError('Expected the default hidden canvas selector, got "$offscreenSelector".');
  }
  final hidden = web.document.getElementById('thermion_canvas__thermion_offscreen') as web.HTMLCanvasElement?;
  if (hidden == null) throw StateError('The hidden offscreen canvas was not created.');
  if (hidden.style.display != 'none') throw StateError('The offscreen canvas must never be visible.');

  await viewer.setPostProcessing(false);
  await (await viewer.getActiveCamera()).lookAt(Vector3(0, 0, 5), focus: Vector3.zero());

  // One cube for both steps; only its color changes between them.
  final material = await app.createUbershaderMaterialInstance(unlit: true);
  await material.setParameterFloat4('baseColorFactor', 0, 1, 0, 1);
  final cube = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
  await viewer.addToScene(cube);

  // 1) A normal swapchain presents the GREEN cube to the visible canvas.
  final swapChain = await app.createSwapChain(nullptr);
  final greenPixel = await _renderCubeInto(app, viewer, swapChain, canvas, scratch, _isGreen, 'green', errors);

  // 2) Switch the cube to RED and render through an offscreen (present-skip)
  //    swapchain: the hidden canvas must show red while the visible canvas
  //    keeps showing the last presented (green) frame.
  await viewer.setRendering(false);
  await app.renderManager.detach(viewer.view, swapChain: swapChain);
  await app.destroySwapChain(swapChain);
  await material.setParameterFloat4('baseColorFactor', 1, 0, 0, 1);

  final offscreen = await app.createOffscreenSwapChain(0);
  final redPixel = await _renderCubeInto(app, viewer, offscreen, hidden, scratch, _isRed, 'red', errors);

  final visiblePixel = _sampleCenter(scratch, canvas);
  if (!_isGreen(visiblePixel)) {
    throw StateError('Visible canvas must still show the green frame: RGBA ${visiblePixel.toList()}.');
  }

  await app.destroySwapChain(offscreen);
  return 'visible green RGBA ${greenPixel.toList()}, offscreen red RGBA ${redPixel.toList()}, '
      'visible stayed green RGBA ${visiblePixel.toList()}, device exported';
}

Future<void> main() async {
  try {
    final summary = await renderCube();
    finishWebGpuCheck(true.toJS, 'Chromium WebGPU checks passed: $summary.'.toJS);
  } catch (error, stack) {
    finishWebGpuCheck(false.toJS, '$error\n$stack'.toJS);
  }
}
