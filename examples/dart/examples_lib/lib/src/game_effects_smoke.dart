import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// GPU smoke: a single draw call of billboarded puffs generated entirely in
/// the vertex shader (one puff per 6 vertices of a degenerate mesh). Puffs
/// rise, stretch, spin and spiral outward while wind bends the plume; the
/// fragment shader shapes each quad with a soft radial falloff and
/// domain-warped fbm turbulence.
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
  await camera.lookAt(Vector3(0.35, 1.3, 3.6), focus: Vector3(0.3, 1.0, 0));

  await setDarkSkybox(viewer);

  const puffCount = 40;

  final smoke = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "smoke",
  );
  await smoke.setParameterFloat4("baseColor", 0.34, 0.36, 0.42, 1.0);
  await smoke.setParameterFloat("time", 4.6);
  await smoke.setParameterFloat("puffCount", puffCount.toDouble());
  await smoke.setParameterFloat("riseSpeed", 0.5);
  await smoke.setParameterFloat("expandSpeed", 0.22);
  await smoke.setParameterFloat("swirlAmount", 1.1);
  await smoke.setParameterFloat("baseSize", 0.35);
  await smoke.setParameterFloat("noiseScale", 3.2);
  await smoke.setParameterFloat("lifetime", 4.5);

  await viewer.createGeometry(
    dummyBillboardQuads(puffCount),
    materialInstances: [smoke],
  );

  effectAnimators.add((t) async {
    await smoke.setParameterFloat("time", t);
  });
}
