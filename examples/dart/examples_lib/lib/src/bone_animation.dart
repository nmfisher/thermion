import 'package:thermion_dart/thermion_dart.dart';

/// Loads the BusterDrone glTF, adds an animation component, and plays its first
/// animation clip on loop. Requires per-frame animation ticking -- the gallery
/// render loop handles this automatically.
Future<void> setupBoneAnimation(
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
  await camera.lookAt(Vector3(3, 2, 3), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  final asset = await viewer.loadGltf("$assetsDir/BusterDrone/scene.gltf");
  await asset.transformToUnitCube();
  await asset.addAnimationComponent();
  await asset.playGltfAnimation(0, loop: true);
}
