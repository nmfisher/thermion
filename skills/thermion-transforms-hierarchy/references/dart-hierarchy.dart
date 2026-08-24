// Pure-Dart headless example: scene-graph hierarchy. Two cubes — a parent and
// a child parented via FilamentApp.setParent — then the parent moves and the
// child follows.
//
// Run with:  dart run dart_hierarchy.dart [assets_dir]
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/examples_lib (transforms_and_hierarchy setup) in
// the thermion repository.

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

  final parent = await viewer.loadGltf(assetUri('cube.glb'));
  await parent.transformToUnitCube();

  final child = await viewer.loadGltf(assetUri('cube.glb'));
  await child.transformToUnitCube();
  await child.setTransform(Matrix4.translation(Vector3(1.0, 0.0, 0.0)));

  // Parent the child to the parent — from now on the child follows.
  await viewer.app.setParent(child.entity, parent.entity);

  // Moving the parent carries the (locally offset) child with it.
  await parent.setTransform(Matrix4.translation(Vector3(-1.0, 0.0, 0.0)));

  // Capture a frame for verification.
  final result = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final png = await pixelBufferToPng(result.first.$2, width, height,
      hasAlpha: true, isFloat: true);
  await io.File('hierarchy.png').writeAsBytes(png);
  print('Wrote hierarchy.png');

  io.exit(0);
}
