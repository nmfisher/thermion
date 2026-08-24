import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Animated water surface: three Gerstner waves displace a subdivided grid
/// in the vertex shader (with finite-difference normals), while the fragment
/// shader mixes deep/sky colors by fresnel, adds sun glints and crest foam.
Future<void> setupWater(
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
  await camera.lookAt(Vector3(0, 2.2, 5.0), focus: Vector3(0, 0, 0));

  await setDarkSkybox(viewer);

  final water = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "water",
  );
  await water.setParameterFloat4("deepColor", 0.02, 0.09, 0.14, 0.92);
  await water.setParameterFloat4("skyColor", 0.35, 0.55, 0.75, 1.0);
  await water.setParameterFloat4("foamColor", 0.92, 0.97, 1.0, 1.0);
  await water.setParameterFloat3("sunDirection", -0.45, -0.8, -0.35);
  await water.setParameterFloat("time", 2.0);
  await water.setParameterFloat("waveHeight", 0.18);
  await water.setParameterFloat("waveFrequency", 1.6);
  await water.setParameterFloat("waveSpeed", 1.5);
  await water.setParameterFloat("foamAmount", 0.55);
  await water.setParameterFloat("specularPower", 140.0);
  await water.setParameterFloat("specularIntensity", 1.4);

  final surface = await viewer.createGeometry(
    subdividedPlane(width: 12.0, depth: 12.0, subdivisionsX: 96, subdivisionsZ: 96),
    materialInstances: [water],
  );
  await surface.setTransform(Matrix4.translation(Vector3(0, 0, 0)));
}
