import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Shore waves: swells shoal as they approach an analytic shoreline, then
/// break into a pulsing foam line that runs along the beach. Deep water
/// fades to turquoise shallows; past the shoreline the water melts into a
/// sand plane (same shoreline function) with a wet wash band. All from
/// world position - no depth texture needed since the scene geometry is
/// under our control.
Future<void> setupShoreWaves(
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
  await camera.lookAt(Vector3(0, 2.6, -5.6), focus: Vector3(0, -0.2, 1.0));

  await setDarkSkybox(viewer);

  // Sand beach behind the shoreline, just below the water plane.
  final sand = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "sand",
  );
  await sand.setParameterFloat4("sandColor", 0.72, 0.62, 0.46, 1.0);
  await sand.setParameterFloat("time", 2.0);
  final beach = await viewer.createGeometry(
    subdividedPlane(width: 20.0, depth: 8.0, subdivisionsX: 8, subdivisionsZ: 8),
    materialInstances: [sand],
  );
  await beach.setTransform(Matrix4.translation(Vector3(0, -0.05, 4.2)));

  final water = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "shore_waves",
  );
  await water.setParameterFloat4("deepColor", 0.008, 0.07, 0.12, 1.0);
  await water.setParameterFloat4("shallowColor", 0.05, 0.55, 0.55, 1.0);
  await water.setParameterFloat4("skyColor", 0.40, 0.55, 0.68, 1.0);
  await water.setParameterFloat4("foamColor", 0.94, 0.98, 1.0, 1.0);
  await water.setParameterFloat3("sunDirection", -0.45, -0.35, -0.8);
  await water.setParameterFloat("time", 2.0);
  await water.setParameterFloat("waveHeight", 0.30);
  await water.setParameterFloat("waveFrequency", 1.35);
  await water.setParameterFloat("waveSpeed", 1.5);
  await water.setParameterFloat("foamAmount", 1.0);
  await water.setParameterFloat("detailStrength", 1.0);

  final surface = await viewer.createGeometry(
    subdividedPlane(width: 18.0, depth: 12.0, subdivisionsX: 150, subdivisionsZ: 150),
    materialInstances: [water],
  );
  await surface.setTransform(Matrix4.translation(Vector3(0, 0, -3)));

  effectAnimators.add((t) async {
    await water.setParameterFloat("time", t);
    // The sand's swash line is phase-locked to the water's breaker pulse.
    await sand.setParameterFloat("time", t);
  });
}
