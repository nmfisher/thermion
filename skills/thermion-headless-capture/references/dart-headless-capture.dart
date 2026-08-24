// Pure-Dart headless example: capture the same frame twice — once as HDR
// float pixels, once as 8-bit — demonstrating the capture pixel formats.
//
// Run with:  dart run dart_headless_capture.dart [assets_dir]
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/cli_headless/bin/render_demo.dart in the thermion
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
  await camera.lookAt(Vector3(3, 3, 3), focus: Vector3(0, 0, 0));

  await viewer.loadSkybox(assetUri('default_env_skybox.ktx'));
  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  final asset = await viewer.loadGltf(assetUri('cube.glb'));
  await asset.transformToUnitCube();

  // HDR float capture.
  final floatResult = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final floatPng = await pixelBufferToPng(floatResult.first.$2, width, height,
      hasAlpha: true, isFloat: true);
  await io.File('capture_hdr.png').writeAsBytes(floatPng);
  print('Wrote capture_hdr.png');

  // 8-bit capture (isFloat must match!).
  final byteResult = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.UBYTE,
  );
  final bytePng = await pixelBufferToPng(byteResult.first.$2, width, height,
      hasAlpha: true, isFloat: false);
  await io.File('capture_8bit.png').writeAsBytes(bytePng);
  print('Wrote capture_8bit.png');

  // Skip Filament teardown — it can race gltfio material-instance destruction
  // and panic noisily after the PNGs are already flushed.
  io.exit(0);
}
