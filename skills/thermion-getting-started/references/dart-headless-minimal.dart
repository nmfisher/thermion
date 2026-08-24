// Minimal pure-Dart headless Thermion program: sets up an offscreen renderer,
// loads the canonical hello-world scene (cube + skybox + IBL + sun), and
// captures one frame to a PNG. No Flutter, no window.
//
// Run with:  dart run dart_headless_minimal.dart [assets_dir] [output.png]
// (defaults: assets_dir=examples/assets, output=cube.png)
//
// Adapted from examples/dart/cli_headless/bin/render_demo.dart in the thermion
// repository.

import 'dart:io' as io;

import 'package:thermion_dart/thermion_dart.dart';
// FFIFilamentApp is not exported from the public barrel — import from src,
// exactly as the canonical examples do:
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

Future<void> main(List<String> argv) async {
  final assetsDir = argv.isNotEmpty ? argv.first : 'examples/assets';
  final outPath = argv.length > 1 ? argv[1] : 'cube.png';
  const width = 512, height = 512;
  // In pure Dart, assets are addressed with file:// URIs.
  final assetUri = (String rel) => 'file://$assetsDir/$rel';

  // 1) Engine. The default resource loader does raw File reads and chokes on
  //    the file:// scheme, so strip it in a custom loadResource.
  await FFIFilamentApp.create(
    config: FFIFilamentConfig(
      loadResource: (uri) async {
        final path = uri.replaceAll('file://', '');
        return io.File(path).readAsBytes();
      },
    ),
  );
  final app = FilamentApp.instance!;

  // 2) Offscreen rendering target + viewer.
  final swapChain = await app.createHeadlessSwapChain(width, height);
  final viewer = ThermionViewerFFI(app: app as FFIFilamentApp);
  await viewer.initialized;
  await app.renderManager.attach(viewer.view, swapChain);
  await viewer.setViewport(width, height);

  // 3) The canonical hello-world scene.
  await viewer.loadSkybox(assetUri('default_env_skybox.ktx'));
  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  final asset = await viewer.loadGltf(assetUri('cube.glb'));
  await asset.transformToUnitCube();

  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(3, 3, 3), focus: Vector3(0, 0, 0));

  // 4) Capture one frame to a PNG.
  final result = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final pixels = result.first.$2;
  final png = await pixelBufferToPng(pixels, width, height,
      hasAlpha: true, isFloat: true);
  await io.File(outPath).writeAsBytes(png);
  print('Wrote $outPath');

  // Hard-exit: Filament teardown can race gltfio material-instance destruction
  // and panic noisily; the PNG is already flushed, so just exit cleanly.
  io.exit(0);
}
