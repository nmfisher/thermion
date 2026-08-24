// Pure-Dart headless example: procedural geometry — the five GeometryUtils
// primitives arranged in a row, plus a hand-built pyramid from raw vertices
// and indices.
//
// Run with:  dart run dart_primitives_and_pyramid.dart [assets_dir]
// (default assets_dir=examples/assets)
//
// Adapted from examples/dart/examples_lib (geometry_primitives and
// custom_geometry setups) in the thermion repository.

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
  await camera.lookAt(Vector3(0, 4, 8), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox(assetUri('default_env_skybox.ktx'));
  await viewer.loadIbl(assetUri('default_env_ibl.ktx'));

  // The five primitives, in a row.
  final cube = await viewer.createGeometry(GeometryUtils.cube());
  await cube.setTransform(Matrix4.translation(Vector3(-4, 0, 0)));

  final sphere = await viewer.createGeometry(GeometryUtils.sphere());
  await sphere.setTransform(Matrix4.translation(Vector3(-2, 0, 0)));

  final cylinder = await viewer.createGeometry(GeometryUtils.cylinder(uvs: false));
  await cylinder.setTransform(Matrix4.translation(Vector3(0, 0, 0)));

  final conic = await viewer.createGeometry(GeometryUtils.conic(uvs: false));
  await conic.setTransform(Matrix4.translation(Vector3(2, 0, 0)));

  final plane = await viewer.createGeometry(GeometryUtils.plane());
  await plane.setTransform(Matrix4.translation(Vector3(4, 0, 0)));

  // A custom pyramid: 5 vertices, 6 triangles (2 base + 4 sides).
  final vertices = Float32List.fromList([
    -1.0, -1.0, -1.0, // 0
     1.0, -1.0, -1.0, // 1
     1.0, -1.0,  1.0, // 2
    -1.0, -1.0,  1.0, // 3
     0.0,  1.0,  0.0, // 4 (apex)
  ]);
  final indices = <int>[
    0, 2, 1, 0, 3, 2, // base
    0, 1, 4, 1, 2, 4, // sides
    2, 3, 4, 3, 0, 4,
  ];
  final pyramid = await viewer.createGeometry(Geometry(vertices, indices));
  await pyramid.setTransform(Matrix4.translation(Vector3(0, 2, -4)));

  // Capture a frame.
  final result = await app.capture(
    swapChain,
    view: viewer.view,
    pixelDataFormat: PixelDataFormat.RGBA,
    pixelDataType: PixelDataType.FLOAT,
  );
  final png = await pixelBufferToPng(result.first.$2, width, height,
      hasAlpha: true, isFloat: true);
  await io.File('geometry.png').writeAsBytes(png);
  print('Wrote geometry.png');

  io.exit(0);
}
