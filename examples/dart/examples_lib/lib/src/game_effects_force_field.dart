import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Force-field bubble: an additive-blended sphere with a fresnel silhouette
/// (plus a hot rim lip), a wobbling hexagonal energy lattice with per-cell
/// twinkle, and expanding impact ripples from periodic hits. A small bright
/// core cube sits inside as the shield generator.
Future<void> setupForceField(
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
  await camera.lookAt(Vector3(0, 0.7, 3.8), focus: Vector3(0, 0.05, 0));

  await setDarkSkybox(viewer);

  // Bright core cube so the additive bubble has something to protect.
  final core = await viewer.createGeometry(GeometryUtils.cube());
  await core.setTransform(Matrix4.identity()
    ..scaleByVector3(Vector3.all(0.4)));

  final field = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "force_field",
  );
  await field.setParameterFloat4("baseColor", 0.30, 0.55, 1.0, 1.0);
  await field.setParameterFloat("time", 2.25);
  await field.setParameterFloat("fresnelPower", 2.2);
  await field.setParameterFloat("hexScale", 20.0);
  await field.setParameterFloat("hexStrength", 1.15);
  await field.setParameterFloat3("hitDirection", 0.4, 0.25, 0.88);
  await field.setParameterFloat("hitAge", 0.35);

  final bubble = await viewer.createGeometry(
    GeometryUtils.sphere(latitudeBands: 48, longitudeBands: 64),
    materialInstances: [field],
  );
  // GeometryUtils.sphere has radius 1.0; scale to a radius-1.2 bubble.
  await bubble
      .setTransform(Matrix4.identity()..scaleByVector3(Vector3.all(1.2)));

  // A new hit every 1.9s from a rotating ring of directions (biased toward
  // the camera so ripples stay visible), with the ripple age driven from
  // wall-clock time.
  const hitPeriod = 1.9;
  final hitDirections = [
    Vector3(0.45, 0.2, 0.87),
    Vector3(-0.6, 0.5, 0.62),
    Vector3(0.1, -0.85, 0.5),
    Vector3(0.85, -0.1, 0.52),
  ];
  var hitIndex = 0;
  var lastHitTime = 0.0;
  effectAnimators.add((t) async {
    if (t - lastHitTime >= hitPeriod) {
      lastHitTime = t;
      hitIndex = (hitIndex + 1) % hitDirections.length;
      final d = hitDirections[hitIndex];
      await field.setParameterFloat3("hitDirection", d.x, d.y, d.z);
    }
    await field.setParameterFloat("hitAge", t - lastHitTime);
    await field.setParameterFloat("time", t);
  });
}
