import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// GPU fire: a single draw call of camera-facing flame tongues (16) plus
/// ember sparks (20), all generated in the vertex shader. The fragment
/// shader scrolls domain-warped noise downward so its features lick
/// upward, shapes each tongue with a height-tapered mask, and colors it
/// through a blackbody ramp (white -> yellow -> orange -> red). Embers
/// rise from the flame, wobble, and fade from white-hot to red.
Future<void> setupFire(
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
  await camera.lookAt(Vector3(0, 0.75, 3.0), focus: Vector3(0, 0.55, 0));

  await setDarkSkybox(viewer);

  const flameCount = 20;
  const emberCount = 28;

  final fire = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "fire",
  );
  await fire.setParameterFloat("time", 4.6);
  await fire.setParameterFloat("flameCount", flameCount.toDouble());
  await fire.setParameterFloat("emberCount", emberCount.toDouble());
  await fire.setParameterFloat("flameHeight", 1.45);
  await fire.setParameterFloat("flameWidth", 0.34);
  await fire.setParameterFloat("noiseScale", 2.7);
  await fire.setParameterFloat("scrollSpeed", 3.0);
  await fire.setParameterFloat("windLean", 0.30);
  await fire.setParameterFloat("emberLifetime", 1.9);

  await viewer.createGeometry(
    dummyBillboardQuads(flameCount + emberCount),
    materialInstances: [fire],
  );

  effectAnimators.add((t) async {
    await fire.setParameterFloat("time", t);
  });
}
