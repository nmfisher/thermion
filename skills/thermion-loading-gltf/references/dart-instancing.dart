// Pure-Dart headless example: GPU instancing via loadGltf(initialInstances: N)
// with a transform per instance.
//
// Run with:  dart run dart_instancing.dart [assets_dir]
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/examples_lib (instancing setup) in the thermion
// repository.

import 'dart:io' as io;

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

Future<void> main(List<String> argv) async {
  final assetsDir = argv.isNotEmpty ? argv.first : 'examples/assets';
  const width = 512, height = 512;
  final assetUri = (String rel) => 'file://$assetsDir/$rel';

  await FFIFilamentApp.create(
    config: FFIFilamentConfig(
      loadResource: (uri) async =>
          io.File(uri.replaceAll('file://', '')).readAsBytes(),
    ),
  );
  final app = FilamentApp.instance!;
  final swapChain = await app.createHeadlessSwapChain(width, height);
  final viewer = ThermionViewerFFI(app: app as FFIFilamentApp);
  await viewer.initialized;
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.setViewport(width, height);

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
      near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);
  await camera.lookAt(Vector3(3, 3, 3), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox(assetUri('default_env_skybox.ktx'));
  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));

  // One asset, four pre-allocated GPU instances.
  final asset = await viewer.loadGltf(assetUri('cube.glb'), initialInstances: 4);
  await asset.transformToUnitCube();

  final offsets = [-2.25, -0.75, 0.75, 2.25];
  for (var i = 0; i < offsets.length; i++) {
    final instance = await asset.getInstance(i);
    await instance.setTransform(Matrix4.translation(Vector3(offsets[i], 0, 0)));
  }

  // Capture a frame so the run produces something visible.
  final result = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final png = await pixelBufferToPng(result.first.$2, width, height,
      hasAlpha: true, isFloat: true);
  await io.File('instances.png').writeAsBytes(png);
  print('Wrote instances.png');

  io.exit(0);
}
