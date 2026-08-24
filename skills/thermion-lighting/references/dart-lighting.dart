// Pure-Dart headless example: IBL + skybox + sun, plus a three-point
// (key/fill/rim) setup of colored point lights.
//
// Run with:  dart run dart_lighting.dart [assets_dir]
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/examples_lib (lighting_setup) and
// examples/dart/cli_headless (point-light rig) in the thermion repository.

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
  await camera.lookAt(Vector3(2, 2, 2), focus: Vector3(0, 0, 0));

  // Subject.
  final asset = await viewer.loadGltf(assetUri('cube.glb'));
  await asset.transformToUnitCube();

  // Environment: IBL (ambient/reflection lighting) + visible skybox from the
  // same HDRI.
  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));
  await viewer.loadSkybox(assetUri('default_env_skybox.ktx'));

  // A directional sun.
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, 0)));

  // Three-point rig: warm key, cool fill, white rim. Intensity for point
  // lights is luminous flux in lumens; falloffRadius is world units.
  await viewer.addDirectLight(DirectLight.point(
    position: Vector3(3.5, 2.5, 2.0),
    color: LinearColor(1.0, 0.82, 0.55),
    intensity: 90000,
    falloffRadius: 8.0,
  ));
  await viewer.addDirectLight(DirectLight.point(
    position: Vector3(-3.2, 1.6, -1.5),
    color: LinearColor(0.55, 0.72, 1.0),
    intensity: 60000,
    falloffRadius: 8.0,
  ));
  await viewer.addDirectLight(DirectLight.point(
    position: Vector3(0.0, 3.8, -3.5),
    color: LinearColor(1.0, 1.0, 1.0),
    intensity: 70000,
    falloffRadius: 8.0,
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
  await io.File('lighting.png').writeAsBytes(png);
  print('Wrote lighting.png');

  io.exit(0);
}
