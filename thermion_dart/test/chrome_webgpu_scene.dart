import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart' as web_bindings show NativeLibrary;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart_web.dart';
import 'package:web/web.dart' as web;

@JS('finishWebGpuCheck')
external void finishWebGpuCheck(JSBoolean passed, JSString message);

/// Renders the red cube into [swapChain] and waits until the center pixel
/// of [readCanvas] shows it. [readCanvas] is the visible canvas for a
/// presenting swapchain, or the hidden offscreen canvas for a
/// present-skip one.
Future<Uint8ClampedList> _renderCubeInto(
  FFIFilamentApp app,
  ThermionViewerFFI viewer,
  SwapChain swapChain,
  web.HTMLCanvasElement readCanvas,
  List<String> errors,
) async {
  final sample = web.HTMLCanvasElement()
    ..width = readCanvas.width
    ..height = readCanvas.height;
  final context = sample.getContext('2d') as web.CanvasRenderingContext2D;

  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.setRendering(true);
  await viewer.view.setViewport(readCanvas.width, readCanvas.height);
  await viewer.setPostProcessing(false);
  await (await viewer.getActiveCamera()).lookAt(Vector3(0, 0, 5), focus: Vector3.zero());

  final material = await app.createUbershaderMaterialInstance(unlit: true);
  await material.setParameterFloat4('baseColorFactor', 1, 0, 0, 1);
  final cube = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
  await viewer.addToScene(cube);

  late Uint8ClampedList pixel;
  for (var frame = 0; frame < 30; frame++) {
    await app.render();
    context.drawImage(readCanvas, 0, 0);
    pixel = context.getImageData(readCanvas.width ~/ 2, readCanvas.height ~/ 2, 1, 1).data.toDart;
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    if (pixel[0] > 100 && pixel[1] < 40 && pixel[2] < 40 && pixel[3] > 200) return pixel;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('Expected a red center pixel. Got RGBA ${pixel.toList()}.');
}

Future<String> renderCube() async {
  final canvas = web.document.getElementById('thermion_canvas') as web.HTMLCanvasElement;

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
  // the extension must fall back to the engine's default canvas.
  final offscreenSelector = app.offscreenCanvasSelector();
  if (offscreenSelector != '#thermion_canvas__thermion_offscreen') {
    throw StateError('Expected the default hidden canvas selector, got "$offscreenSelector".');
  }
  final hidden = web.document.getElementById('thermion_canvas__thermion_offscreen') as web.HTMLCanvasElement?;
  if (hidden == null) throw StateError('The hidden offscreen canvas was not created.');
  if (hidden.style.display != 'none') throw StateError('The offscreen canvas must never be visible.');

  // 1) A normal swapchain still presents to the visible canvas.
  final swapChain = await app.createSwapChain(nullptr);
  final pixel = await _renderCubeInto(app, viewer, swapChain, canvas, errors);

  // 2) An offscreen (present-skip) swapchain renders into the hidden canvas
  //    and never touches the visible one.
  await viewer.setRendering(false);
  await app.renderManager.detach(viewer.view, swapChain: swapChain);
  await app.destroySwapChain(swapChain);

  // Blank the visible canvas so any later presentation would show up.
  final visibleContext = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  visibleContext.clearRect(0, 0, canvas.width, canvas.height);

  final offscreen = await app.createOffscreenSwapChain(0);
  final offscreenPixel = await _renderCubeInto(app, viewer, offscreen, hidden, errors);

  // The visible canvas must have stayed blank while the offscreen frames
  // rendered: nothing was presented to it.
  final visiblePixel = visibleContext.getImageData(canvas.width ~/ 2, canvas.height ~/ 2, 1, 1).data.toDart;
  if (visiblePixel[3] != 0) {
    throw StateError('Offscreen swapchain presented to the visible canvas: RGBA ${visiblePixel.toList()}.');
  }

  await app.destroySwapChain(offscreen);
  return 'presented RGBA ${pixel.toList()}, offscreen RGBA ${offscreenPixel.toList()}, '
      'visible canvas untouched, device exported';
}

Future<void> main() async {
  try {
    final summary = await renderCube();
    finishWebGpuCheck(true.toJS, 'Chromium WebGPU checks passed: $summary.'.toJS);
  } catch (error, stack) {
    finishWebGpuCheck(false.toJS, '$error\n$stack'.toJS);
  }
}
