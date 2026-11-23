@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:web/web.dart' as web;

import 'helpers.dart';

void main() {
  test('WebGPU presents an unlit red cube in Chromium', () async {
    final canvas = web.document.getElementById('thermion_canvas') as web.HTMLCanvasElement;
    canvas
      ..width = 64
      ..height = 64;
    final sample = web.HTMLCanvasElement()
      ..width = canvas.width
      ..height = canvas.height;
    final context = sample.getContext('2d') as web.CanvasRenderingContext2D;

    final helper = TestHelper('chrome_webgpu_scene', backend: Backend.WEBGPU);
    await helper.setup();
    final app = FilamentApp.instance! as FFIFilamentApp;
    final viewer = ThermionViewerFFI(app: app);
    await viewer.initialized;
    final swapChain = await app.createSwapChain(nullptr);
    try {
      await app.renderManager.attach(viewer.view, swapChain);
      await viewer.view.setViewport(canvas.width, canvas.height);
      await viewer.setPostProcessing(false);
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(0, 0, 5), focus: Vector3.zero());

      final material = await app.createUbershaderMaterialInstance(unlit: true);
      await material.setParameterFloat4('baseColorFactor', 1, 0, 0, 1);
      final cube = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
      await viewer.addToScene(cube);

      // Sample what the browser presents to the canvas.
      late Uint8ClampedList pixel;
      for (var frame = 0; frame < 30; frame++) {
        await app.render();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        context.drawImage(canvas, 0, 0);
        pixel = context.getImageData(canvas.width ~/ 2, canvas.height ~/ 2, 1, 1).data.toDart;
        if (pixel[0] > 100 && pixel[1] < 40 && pixel[2] < 40) break;
      }
      expect(pixel[0], greaterThan(100), reason: 'Center pixel RGBA ${pixel.toList()}');
      expect(pixel[1], lessThan(40));
      expect(pixel[2], lessThan(40));
      await viewer.destroyAsset(cube);
    } finally {
      await viewer.dispose();
      await app.destroySwapChain(swapChain);
    }
  });
}
