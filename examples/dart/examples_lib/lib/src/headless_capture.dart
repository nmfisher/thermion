import 'package:thermion_dart/thermion_dart.dart';

/// Builds a simple but well-lit scene (cube + skybox + IBL) suitable for a
/// single headless PNG capture.
///
/// NOTE: The original CLI example demonstrated multi-frame capture with
/// different camera angles and pixel formats. The capture logic is
/// headless-only and handled by the runner; this setup only provides the scene.
Future<void> setupHeadlessCapture(
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
