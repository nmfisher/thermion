import 'package:thermion_dart/thermion_dart.dart';

/// Animation showcase: the BusterDrone playing its skinned skeletal animation
/// (looped) alongside a cube whose morph targets are blended -- both driven by
/// the gallery's per-frame animation tick.
///
/// Absorbs gltf_animation + morph_targets (+ the duplicate bone_animation).
Future<void> setupAnimation(
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
  await camera.lookAt(Vector3(0, 2.5, 7), focus: Vector3(0, 0.5, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -0.5)));
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");

  // Skinned skeletal animation.
  final drone = await viewer.loadGltf("$assetsDir/BusterDrone/scene.gltf");
  await drone.transformToUnitCube();
  await drone.setTransform(Matrix4.translation(Vector3(-2.4, 0.5, 0)));
  await drone.addAnimationComponent();
  await drone.playGltfAnimation(0, loop: true);

  // Morph targets: blend the first two weights.
  final morph =
      await viewer.loadGltf("$assetsDir/cube_with_morph_targets.glb");
  await morph.transformToUnitCube();
  await morph.setTransform(
    Matrix4.translation(Vector3(2.4, 0.5, 0)) *
        Matrix4.diagonal3(Vector3.all(0.8)),
  );

  final children = await morph.getChildEntities();
  ThermionEntity morphEntity = children.first;
  for (final child in children) {
    final names = await morph.getMorphTargetNames(entity: child);
    if (names.isNotEmpty) {
      morphEntity = child;
      break;
    }
  }
  final names = await morph.getMorphTargetNames(entity: morphEntity);
  final weights = List<double>.filled(names.length, 0.0);
  if (names.length >= 2) {
    weights[0] = 0.5;
    weights[1] = 0.5;
  } else if (names.isNotEmpty) {
    weights[0] = 1.0;
  }
  await morph.setMorphTargetWeights(morphEntity, weights);
}
