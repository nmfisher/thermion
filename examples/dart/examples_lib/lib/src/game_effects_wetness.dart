import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Rain-soaked ground with pooled clear coat, rough aggregate, animated
/// multi-scale drops, and an environment-driven grazing reflection.
Future<void> setupWetness(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 32.0,
  );
  await camera.lookAt(Vector3(4.5, 2.15, 5.2), focus: Vector3(0, 0, -0.7));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx');
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.18);

  final wetness = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'wetness',
  );
  await wetness.setParameterFloat('time', 2.35);
  await wetness.setParameterFloat('rainAmount', 1.0);
  await viewer.createGeometry(
    subdividedPlane(width: 10, depth: 9, subdivisionsX: 72, subdivisionsZ: 72),
    materialInstances: [wetness],
  );
  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-0.45, -0.72, -0.53),
      intensity: 65000,
    ),
  );
  effectAnimators.add((t) async {
    await wetness.setParameterFloat('time', t);
  });
}
