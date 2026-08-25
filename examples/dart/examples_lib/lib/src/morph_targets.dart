import 'package:thermion_dart/thermion_dart.dart';

/// Loads a cube with morph targets and applies a named target.
Future<void> setupMorphTargets(
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
  await camera.lookAt(Vector3(1.5, 1.5, 1.5), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  final asset = await viewer.loadGltf("$assetsDir/cube_with_morph_targets.glb");
  await asset.transformToUnitCube();

  // Each set identifies the renderable entity and its targets, including their
  // names and indices. This asset has one renderable with one named target.
  final morphTargets = (await asset.getMorphTargetSets()).single;
  final targetName = morphTargets.targets.single.name!;
  await morphTargets.setWeight(targetName, 1.0);
}
