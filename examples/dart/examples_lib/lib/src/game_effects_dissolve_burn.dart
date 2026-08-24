import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Dissolve/burn: a noise threshold eats the mesh away while the receding
/// front burns - white-hot at the very edge through orange to deep red,
/// flickering like combustion, with ember sparks and a charring gradient
/// ahead of the front. `threshold` 0 = intact, 1 = fully dissolved. Opaque
/// blending with `discard` keeps depth-writing correct, and the noise is
/// sampled in object space so the burn is pinned to the mesh.
Future<void> setupDissolveBurn(
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
  await camera.lookAt(Vector3(1.4, 0.9, 1.4), focus: Vector3(0, 0, 0));

  await setDarkSkybox(viewer);

  final asset = await viewer.loadGltf("$assetsDir/FlightHelmet/FlightHelmet.gltf");
  await asset.transformToUnitCube();

  final dissolve = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "dissolve_burn",
  );
  await dissolve.setParameterFloat4("baseColor", 0.16, 0.13, 0.12, 1.0);
  await dissolve.setParameterFloat4("edgeColor", 1.0, 0.45, 0.1, 1.0);
  await dissolve.setParameterFloat("threshold", 0.5);
  await dissolve.setParameterFloat("edgeWidth", 0.13);
  await dissolve.setParameterFloat("edgeIntensity", 3.0);
  await dissolve.setParameterFloat("noiseScale", 3.4);
  await dissolve.setParameterFloat("time", 1.2);

  await asset.setMaterialInstanceForAll(dissolve);

  // One full burn per 3.5s cycle, repeating.
  effectAnimators.add((t) async {
    final cycle = t % 3.5;
    await dissolve.setParameterFloat("threshold", cycle / 3.5 * 0.95);
    await dissolve.setParameterFloat("time", t);
  });
}
