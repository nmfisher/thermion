import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart' as web_bindings show NativeLibrary;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:web/web.dart' as web;

@JS('finishWebGpuCheck')
external void finishWebGpuCheck(JSBoolean passed, JSString message);

Future<Uint8ClampedList> renderCube() async {
  final canvas = web.document.getElementById('thermion_canvas') as web.HTMLCanvasElement;
  final sample = web.HTMLCanvasElement()
    ..width = canvas.width
    ..height = canvas.height;
  final context = sample.getContext('2d') as web.CanvasRenderingContext2D;

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
  final swapChain = await app.createSwapChain(nullptr);
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.setRendering(true);
  await viewer.view.setViewport(canvas.width, canvas.height);
  await viewer.setPostProcessing(false);
  await (await viewer.getActiveCamera()).lookAt(Vector3(0, 0, 5), focus: Vector3.zero());

  final material = await app.createUbershaderMaterialInstance(unlit: true);
  await material.setParameterFloat4('baseColorFactor', 1, 0, 0, 1);
  final cube = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
  await viewer.addToScene(cube);

  late Uint8ClampedList pixel;
  for (var frame = 0; frame < 30; frame++) {
    await app.render();
    context.drawImage(canvas, 0, 0);
    pixel = context.getImageData(canvas.width ~/ 2, canvas.height ~/ 2, 1, 1).data.toDart;
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    if (pixel[0] > 100 && pixel[1] < 40 && pixel[2] < 40 && pixel[3] > 200) return pixel;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError('Expected a red center pixel. Got RGBA ${pixel.toList()}.');
}

Future<void> main() async {
  try {
    final pixel = await renderCube();
    finishWebGpuCheck(true.toJS, 'Chromium presented the red cube. Center pixel RGBA ${pixel.toList()}.'.toJS);
  } catch (error, stack) {
    finishWebGpuCheck(false.toJS, '$error\n$stack'.toJS);
  }
}
