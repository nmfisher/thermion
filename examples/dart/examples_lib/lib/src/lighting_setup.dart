import 'package:thermion_dart/thermion_dart.dart';

/// Loads a cube lit with image-based lighting (skybox + IBL) plus a directional
/// sun light — the most flattering of the lighting configurations.
Future<void> setupLightingSetup(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);
  await camera.lookAt(Vector3(2, 2, 2), focus: Vector3(0, 0, 0));

  final asset = await viewer.loadGltf("$assetsDir/cube.glb");
  await asset.transformToUnitCube();

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, 0)));
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
}
