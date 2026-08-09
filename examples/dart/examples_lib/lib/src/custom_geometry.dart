import 'package:thermion_dart/thermion_dart.dart';

/// Creates a procedural pyramid (custom [Geometry] with hand-specified vertices
/// and indices) to demonstrate that arbitrary mesh data can be rendered without
/// a glTF file.
///
/// NOTE: The original CLI example also applied custom .filamat materials
/// (viewspace, custom attributes). Loading .filamat requires raw file I/O
/// (`dart:io`), so this setup uses the default material instead.
Future<void> setupCustomGeometry(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );
  await camera.lookAt(Vector3(0, 1.5, 4), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  // Custom pyramid: 5 vertices, 6 triangles (2 base + 4 sides).
  final vertices = Float32List.fromList([
    // Base (y = -1)
    -1.0, -1.0, -1.0, // 0
     1.0, -1.0, -1.0, // 1
     1.0, -1.0,  1.0, // 2
    -1.0, -1.0,  1.0, // 3
    // Apex (y = 1)
     0.0,  1.0,  0.0, // 4
  ]);
  final indices = <int>[
    // Base (two triangles)
    0, 2, 1,
    0, 3, 2,
    // Front
    0, 1, 4,
    // Right
    1, 2, 4,
    // Back
    2, 3, 4,
    // Left
    3, 0, 4,
  ];

  final geo = Geometry(vertices, indices);
  await viewer.createGeometry(geo);
}
