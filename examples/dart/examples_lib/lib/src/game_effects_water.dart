import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Animated water surface: four Gerstner waves displace a subdivided grid in
/// the vertex shader (with finite-difference normals and crest/chop foam
/// inputs), while the fragment shader adds two scrolled detail-normal layers,
/// Schlick fresnel deep/sky mixing, a backlit crest subsurface glow, dual-lobe
/// sun glitter, crest foam, and a distance haze that melts the plane edge.
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
  await camera.lookAt(Vector3(0, 1.8, 5.0), focus: Vector3(0, -0.1, 0));

  await setDarkSkybox(viewer);

  final water = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "water",
  );
  await water.setParameterFloat4("deepColor", 0.008, 0.058, 0.090, 0.94);
  await water.setParameterFloat4("skyColor", 0.36, 0.52, 0.72, 1.0);
  await water.setParameterFloat4("foamColor", 0.94, 0.98, 1.0, 1.0);
  await water.setParameterFloat3("sunDirection", -0.55, -0.35, -0.75);
  await water.setParameterFloat("time", 1.7);
  await water.setParameterFloat("waveHeight", 0.36);
  await water.setParameterFloat("waveFrequency", 1.25);
  await water.setParameterFloat("waveSpeed", 1.6);
  await water.setParameterFloat("foamAmount", 1.0);
  await water.setParameterFloat("specularPower", 520.0);
  await water.setParameterFloat("specularIntensity", 4.2);
  await water.setParameterFloat("detailStrength", 1.0);
  await water.setParameterFloat("sssStrength", 0.9);

  final surface = await viewer.createGeometry(
    subdividedPlane(width: 16.0, depth: 16.0, subdivisionsX: 200, subdivisionsZ: 200),
    materialInstances: [water],
  );
  await surface.setTransform(Matrix4.translation(Vector3(0, 0, 0)));

  effectAnimators.add((t) async {
    await water.setParameterFloat("time", t);
  });
}
