import 'package:thermion_dart/thermion_dart.dart';

/// Loads a cube with morph targets and blends the first two targets at 0.5 each
/// to show a mid-morph pose. Requires per-frame animation ticking for the
/// weights to take visual effect.
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

  final asset =
      await viewer.loadGltf("$assetsDir/cube_with_morph_targets.glb");
  await asset.transformToUnitCube();

  // Morph targets live on child (renderable) entities, not the root.
  final children = await asset.getChildEntities();

  // Find the child entity that has morph targets.
  ThermionEntity morphEntity = children.first;
  for (final child in children) {
    final names = await asset.getMorphTargetNames(entity: child);
    if (names.isNotEmpty) {
      morphEntity = child;
      break;
    }
  }

  final names = await asset.getMorphTargetNames(entity: morphEntity);

  // Blend the first two targets equally.
  final weights = List<double>.filled(names.length, 0.0);
  if (names.length >= 2) {
    weights[0] = 0.5;
    weights[1] = 0.5;
  } else if (names.isNotEmpty) {
    weights[0] = 1.0;
  }
  await asset.setMorphTargetWeights(morphEntity, weights);
}
