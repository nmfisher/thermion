import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// GPU fire: camera-facing flame tongues and ember sparks generated in one
/// draw, backed by a second turbulent draw for the dark smoke cap. The fragment
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
  await enableVfxPost(viewer, bloomStrength: 0.48);

  const flameCount = 12;
  const emberCount = 36;

  final fire = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "fire",
  );
  await fire.setParameterFloat("time", 4.6);
  await fire.setParameterFloat("flameCount", flameCount.toDouble());
  await fire.setParameterFloat("emberCount", emberCount.toDouble());
  await fire.setParameterFloat("flameHeight", 1.12);
  await fire.setParameterFloat("flameWidth", 0.27);
  await fire.setParameterFloat("noiseScale", 3.4);
  await fire.setParameterFloat("scrollSpeed", 2.5);
  await fire.setParameterFloat("windLean", 0.22);
  await fire.setParameterFloat("emberLifetime", 1.9);

  await viewer.createGeometry(
    dummyBillboardQuads(flameCount + emberCount),
    materialInstances: [fire],
  );

  final ground = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "fire_ground",
  );
  await ground.setParameterFloat("time", 4.6);
  final emberBed = await viewer.createGeometry(
    GeometryUtils.plane(width: 1.5, height: 1.5),
    materialInstances: [ground],
  );
  await emberBed.setTransform(Matrix4.translation(Vector3(0, -0.015, 0)));

  // Fire without combustion smoke reads as a stylized sprite stack. A
  // compact, dark plume merges the individual tongues into one volume and
  // gives the effect a believable thermal lifecycle.
  const smokeCount = 24;
  final smoke = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "smoke",
  );
  await smoke.setParameterFloat4("baseColor", 0.07, 0.06, 0.065, 1.0);
  await smoke.setParameterFloat("time", 4.6);
  await smoke.setParameterFloat("puffCount", smokeCount.toDouble());
  await smoke.setParameterFloat("riseSpeed", 0.31);
  await smoke.setParameterFloat("expandSpeed", 0.075);
  await smoke.setParameterFloat("swirlAmount", 1.05);
  await smoke.setParameterFloat("baseSize", 0.13);
  await smoke.setParameterFloat("noiseScale", 3.8);
  await smoke.setParameterFloat("lifetime", 4.0);
  await smoke.setParameterFloat("originHeight", 0.52);
  await smoke.setParameterFloat("opacity", 0.32);
  await viewer.createGeometry(
    dummyBillboardQuads(smokeCount),
    materialInstances: [smoke],
  );

  effectAnimators.add((t) async {
    await fire.setParameterFloat("time", t);
    await smoke.setParameterFloat("time", t);
    await ground.setParameterFloat("time", t);
  });
}
