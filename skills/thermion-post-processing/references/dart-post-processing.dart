// Pure-Dart headless example: post-processing — FXAA, bloom, ACES tone-mapped
// warm color grading, and fog.
//
// Run with:  dart run dart_post_processing.dart [assets_dir]
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/examples_lib (post_processing setup) in the
// thermion repository.

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

  // Post-processing gates everything below.
  await viewer.setPostProcessing(true);
  await viewer.setAntiAliasing(false, true, false); // FXAA only
  await viewer.setBloom(true, 0.5);

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
      near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);
  await camera.lookAt(Vector3(3, 2, 3), focus: Vector3(0, 0, 0));

  await viewer.loadSkybox(assetUri('default_env_skybox.ktx'));
  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));

  final asset = await viewer.loadGltf(assetUri('cube.glb'));
  await asset.transformToUnitCube();

  // Warm ACES grading. The grading is caller-owned: dispose the builder and
  // tone mapper after build; detach with setColorGrading(null) when replacing.
  final builder = await viewer.view.createColorGradingBuilder();
  final toneMapper = await ToneMapper.aces(app);
  final grading = await builder
      .toneMapper(toneMapper)
      .quality(QualityLevel.HIGH)
      .exposure(1.2)
      .whiteBalance(0.3, 0.05)
      .contrast(1.1)
      .saturation(1.1)
      .vibrance(1.2)
      .build();
  await builder.dispose();
  await toneMapper.dispose();
  await viewer.view.setColorGrading(grading);

  // Light atmospheric fog.
  await viewer.view.setFogOptions(FogOptions(
    enabled: true,
    density: 0.02,
    linearColor: Vector3(0.8, 0.85, 0.9),
  ));

  // Capture a frame.
  final result = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final png = await pixelBufferToPng(result.first.$2, width, height,
      hasAlpha: true, isFloat: true);
  await io.File('post_processing.png').writeAsBytes(png);
  print('Wrote post_processing.png');

  io.exit(0);
}
