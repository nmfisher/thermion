// Pure-Dart headless example: PBR ubershader (metallic/roughness/base color)
// on one cube, wireframe on another.
//
// Run with:  dart run dart_materials.dart [assets_dir]
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/examples_lib (materials_pbr and
// wireframe_and_flat_shading setups) in the thermion repository.

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
  await camera.lookAt(Vector3(2, 2, 4), focus: Vector3(0, 0, 0));

  // PBR reads best with an environment to reflect.
  await viewer.loadSkybox(assetUri('default_env_skybox.ktx'));
  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, 0)));

  // Left cube: polished copper.
  final pbrAsset = await viewer.loadGltf(assetUri('cube.glb'));
  await pbrAsset.transformToUnitCube();
  await pbrAsset.setTransform(Matrix4.translation(Vector3(-1.2, 0, 0)));

  final mat = await app.createUbershaderMaterial();
  await mat.setMetallicFactor(1.0);
  await mat.setRoughnessFactor(0.15);
  await mat.setBaseColorFactor(0.85, 0.5, 0.2, 1.0);
  await pbrAsset.setMaterialInstanceForAll(mat.materialInstance);

  // Right cube: wireframe. rebuildVertices: true rebuilds vertex buffers with
  // barycentric attributes so the wireframe material can be swapped in freely.
  final wireAsset =
      await viewer.loadGltf(assetUri('cube.glb'), rebuildVertices: true);
  await wireAsset.transformToUnitCube();
  await wireAsset.setTransform(Matrix4.translation(Vector3(1.2, 0, 0)));

  final wireframe = await app.createWireframeMaterialInstance();
  await wireframe.setEdgeColor(0.3, 0.9, 0.3, 1.0);
  await wireframe.setFaceColor(0.05, 0.15, 0.05, 1.0);
  await wireframe.setEdgeWidth(0.5);
  await wireAsset.setMaterialInstanceForAll(wireframe.materialInstance);

  // Capture a frame.
  final result = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final png = await pixelBufferToPng(result.first.$2, width, height,
      hasAlpha: true, isFloat: true);
  await io.File('materials.png').writeAsBytes(png);
  print('Wrote materials.png');

  io.exit(0);
}
