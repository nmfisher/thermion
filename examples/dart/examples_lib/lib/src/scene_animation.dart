import 'package:thermion_dart/thermion_dart.dart';

/// Animation showcase: the BusterDrone playing its skinned skeletal animation
/// on a loop, driven by the gallery's per-frame animation tick.
Future<void> setupAnimation(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(0, 0.35, 2.1), focus: Vector3.zero());

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -0.5)));
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");

  final drone = await viewer.loadGltf("$assetsDir/BusterDrone/scene.gltf");
  final floor = await drone.getChildEntity("Scheibe_Boden_0");
  if (floor != null) {
    await drone.setVisibilityLayer(floor, VisibilityLayers.LAYER_3);
    await viewer.view.setLayerVisibility(VisibilityLayers.LAYER_3, false);
  }
  await drone.transformToUnitCube();
  await drone.addAnimationComponent();
  await drone.playGltfAnimation(0, loop: true);
}
