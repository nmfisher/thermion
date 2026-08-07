import 'package:thermion_dart/thermion_dart.dart';

/// Loads a glTF model, normalises it to the unit cube, frames it with a
/// perspective camera, and adds a skybox + IBL for context.
///
/// `assetsDir` is the base path for assets — a `file://` URI on native (handled
/// by the configured resource loader) or a bare relative path like `assets` on
/// web (fetched over HTTP by the default web resource loader).
Future<void> setupLoadGltf(
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

  final asset = await viewer.loadGltf("$assetsDir/cube.glb");
  await asset.transformToUnitCube();

  await camera.lookAt(Vector3(3.0, 3.0, 3.0), focus: Vector3(0, 0, 0));

  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
}
