// Pure-Dart headless example: a cube floating above a ground plane, lit by a
// shadow-casting sun with PCF shadows and tuned ShadowOptions.
//
// Run with:  dart run dart_shadows.dart [assets_dir]
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/examples_lib (shadows setup) in the thermion
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

  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));

  // 1) A receiver: a ground plane that receives shadows.
  final ground =
      await viewer.createGeometry(GeometryUtils.plane(width: 10, height: 10));
  await ground.setReceiveShadows(true);

  // 2) A caster: a cube floating above the plane.
  final cube = await viewer.loadGltf(assetUri('cube.glb'));
  await cube.transformToUnitCube();
  await cube.setTransform(Matrix4.translation(Vector3(0, 0.5, 0)));

  // 3) A shadow-casting sun, plus per-light shadow tuning.
  final sunEntity = await viewer.addDirectLight(
      DirectLight.sun(castShadows: true, direction: Vector3(-1, -2, -1)));
  await app.lightManager.setShadowOptions(
    sunEntity,
    ShadowOptions(
      mapSize: 1024,
      constantBias: 0.001,
      normalBias: 0.01,
    ),
  );

  // 4) View-level switches.
  await viewer.setShadowsEnabled(true);
  await viewer.setShadowType(ShadowType.PCF);

  // Capture a frame.
  final result = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final png = await pixelBufferToPng(result.first.$2, width, height,
      hasAlpha: true, isFloat: true);
  await io.File('shadows.png').writeAsBytes(png);
  print('Wrote shadows.png');

  io.exit(0);
}
