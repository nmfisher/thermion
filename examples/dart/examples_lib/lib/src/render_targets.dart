import 'package:thermion_dart/thermion_dart.dart';

/// Builds a well-lit scene with a cube, skybox, and IBL.
///
/// NOTE: The original CLI example demonstrated off-screen render-target
/// creation, texture sampling, and multi-pass rendering. That infrastructure
/// is headless-only and requires swapchain access; the runner handles it.
/// This setup provides the scene only.
Future<void> setupRenderTargets(
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
  await camera.lookAt(Vector3(2, 2, 2), focus: Vector3(0, 0, 0));
}
