import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// GPU smoke: a single draw call of billboarded puffs generated entirely in
/// the vertex shader (one puff per 6 vertices of a degenerate mesh). Puffs
/// rise, expand and swirl with per-puff seeds; the fragment shader shapes
/// each quad with a soft radial falloff and drifting fbm turbulence.
Future<void> setupSmoke(
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
  await camera.lookAt(Vector3(0, 1.4, 4.0), focus: Vector3(0, 1.1, 0));

  await setDarkSkybox(viewer);

  const puffCount = 24;

  final smoke = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "smoke",
  );
  await smoke.setParameterFloat4("baseColor", 0.45, 0.47, 0.52, 1.0);
  await smoke.setParameterFloat("time", 2.0);
  await smoke.setParameterFloat("puffCount", puffCount.toDouble());
  await smoke.setParameterFloat("riseSpeed", 0.45);
  await smoke.setParameterFloat("expandSpeed", 0.25);
  await smoke.setParameterFloat("swirlAmount", 1.2);
  await smoke.setParameterFloat("baseSize", 0.3);
  await smoke.setParameterFloat("noiseScale", 3.5);
  await smoke.setParameterFloat("lifetime", 4.0);

  await viewer.createGeometry(
    dummyBillboardQuads(puffCount),
    materialInstances: [smoke],
  );
}
