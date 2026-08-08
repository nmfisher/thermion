import 'package:thermion_dart/thermion_dart.dart';

/// Loads a cube and frames it with a perspective camera at a 28 mm focal length,
/// demonstrating the most common camera setup.
Future<void> setupCameraBasics(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final asset = await viewer.loadGltf("$assetsDir/cube.glb");
  await asset.transformToUnitCube();

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );
  await camera.lookAt(Vector3(1.5, 1.5, 1.5), focus: Vector3(0, 0, 0));
}
