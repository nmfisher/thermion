// Pure-Dart headless example: camera positioning and projections — lookAt,
// lens projection (focal length), and vertical field-of-view projection.
//
// Run with:  dart run dart_camera_projections.dart [assets_dir] [mode]
//   mode: lens | fov  (default lens)
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/examples_lib (camera_basics) in the thermion
// repository.

import 'dart:io' as io;

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

Future<void> main(List<String> argv) async {
  final assetsDir = argv.isNotEmpty ? argv.first : 'examples/assets';
  final mode = argv.length > 1 ? argv[1] : 'lens';
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

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox(assetUri('default_env_skybox.ktx'));
  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));

  final asset = await viewer.loadGltf(assetUri('cube.glb'));
  await asset.transformToUnitCube();

  final camera = await viewer.getActiveCamera();

  if (mode == 'fov') {
    // Explicit vertical field of view (degrees) — deterministic framing.
    await camera.setProjectionFromVerticalFieldOfView(
        45.0, 0.1, 100.0, width / height);
  } else {
    // Physical lens: 28mm focal length by default feel.
    await camera.setLensProjection(
        near: 0.1, far: 100.0, aspect: width / height, focalLength: 28.0);
  }

  // Position the camera and aim it at the origin.
  await camera.lookAt(Vector3(2, 2, 2), focus: Vector3(0, 0, 0));
  print('Camera at ${camera.getPosition()} ($mode mode)');

  // Capture a frame.
  final result = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final png = await pixelBufferToPng(result.first.$2, width, height,
      hasAlpha: true, isFloat: true);
  await io.File('camera_$mode.png').writeAsBytes(png);
  print('Wrote camera_$mode.png');

  io.exit(0);
}
