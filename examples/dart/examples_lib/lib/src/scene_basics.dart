import 'package:thermion_dart/thermion_dart.dart';

/// The gallery entry point: a unit cube under a skybox, image-based lighting,
/// and a directional sun -- the canonical "hello world" scene.
///
/// Absorbs the former camera_basics / headless_capture / input_handlers
/// examples, which were visually identical to this in a live context.
Future<void> setupBasics(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(3, 3, 3), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  final asset = await viewer.loadGltf("$assetsDir/cube.glb");
  await asset.transformToUnitCube();
}
