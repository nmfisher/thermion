import 'package:thermion_dart/thermion_dart.dart';

/// Loads a multi-format model (OBJ here) through the Assimp importer,
/// normalises each mesh to the unit cube, frames it with a perspective
/// camera, and adds a skybox + IBL for context.
///
/// `loadModel` returns one [ThermionAsset] per mesh in the file — unlike
/// [ThermionViewer.loadGltf], which returns a single scene asset. Requires
/// a native build with Assimp enabled (`assimp: true` under
/// `hooks.user_defines.thermion_dart`).
///
/// `assetsDir` is the base path for assets — a `file://` URI on native (handled
/// by the configured resource loader) or a bare relative path like `assets` on
/// web (fetched over HTTP by the default web resource loader).
Future<void> setupLoadModel(
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

  final assets = await viewer.loadModel("$assetsDir/test_cube.obj");
  for (final asset in assets) {
    await asset.transformToUnitCube();
  }

  await camera.lookAt(Vector3(3.0, 3.0, 3.0), focus: Vector3(0, 0, 0));

  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
}
