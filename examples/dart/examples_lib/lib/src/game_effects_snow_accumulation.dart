import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Directional snow loading across a complex mesh. Surface slope, height,
/// wind-scale noise, frost sparkle, and a moving snow line all contribute.
Future<void> setupSnowAccumulation(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: 1,
    focalLength: 32,
  );
  await camera.lookAt(Vector3(1.65, 0.95, 2.15), focus: Vector3(0, 0.02, 0));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx');
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.16);

  final asset =
      await viewer.loadGltf('$assetsDir/FlightHelmet/FlightHelmet.gltf');
  await asset.transformToUnitCube();
  final snow = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'snow_accumulation',
  );
  await snow.setParameterFloat('time', 2.6);
  await snow.setParameterFloat('accumulation', 0.72);
  await asset.setMaterialInstanceForAll(snow);
  await viewer.addDirectLight(
    DirectLight.sun(direction: Vector3(-0.3, -0.82, -0.48), intensity: 90000),
  );
  effectAnimators.add((t) async {
    final cycle = t % 6.0;
    final amount =
        cycle < 3.0 ? 0.28 + cycle * 0.23 : 0.97 - (cycle - 3.0) * 0.23;
    await snow.setParameterFloat('time', t);
    await snow.setParameterFloat('accumulation', amount);
  });
}
