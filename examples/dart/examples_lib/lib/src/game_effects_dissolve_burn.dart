import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Dissolve/burn: a noise threshold eats the mesh away while the receding
/// front glows like embers. `threshold` 0 = intact, 1 = fully dissolved.
/// Opaque blending with `discard` keeps depth-writing correct.
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
  await dissolve.setParameterFloat4("baseColor", 0.35, 0.3, 0.28, 1.0);
  await dissolve.setParameterFloat4("edgeColor", 1.0, 0.45, 0.1, 1.0);
  await dissolve.setParameterFloat("threshold", 0.45);
  await dissolve.setParameterFloat("edgeWidth", 0.08);
  await dissolve.setParameterFloat("edgeIntensity", 2.5);
  await dissolve.setParameterFloat("noiseScale", 4.0);
  await dissolve.setParameterFloat("time", 1.0);

  await asset.setMaterialInstanceForAll(dissolve);
}
