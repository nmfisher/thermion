import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Force-field bubble: an additive-blended sphere with a fresnel silhouette,
/// a hex-cell energy lattice across its surface, and a ripple sweeping from
/// pole to pole. A small bright core cube sits inside as the shield
/// generator.
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
  await camera.lookAt(Vector3(0, 0.9, 4.2), focus: Vector3(0, 0, 0));

  await setDarkSkybox(viewer);

  // Bright core cube so the additive bubble has something to protect.
  final core = await viewer.createGeometry(GeometryUtils.cube());
  await core.setTransform(Matrix4.identity()..scaleByVector3(Vector3.all(0.4)));

  final field = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "force_field",
  );
  await field.setParameterFloat4("baseColor", 0.4, 0.7, 1.0, 1.0);
  await field.setParameterFloat("time", 2.0);
  await field.setParameterFloat("fresnelPower", 2.0);
  await field.setParameterFloat("rippleCount", 6.0);
  await field.setParameterFloat("rippleSpeed", 3.0);
  await field.setParameterFloat("hexScale", 9.0);
  await field.setParameterFloat("hexStrength", 0.9);

  final bubble = await viewer.createGeometry(
    GeometryUtils.sphere(latitudeBands: 48, longitudeBands: 64),
    materialInstances: [field],
  );
  // GeometryUtils.sphere has radius 1.0; scale to a radius-1.2 bubble.
  await bubble
      .setTransform(Matrix4.identity()..scaleByVector3(Vector3.all(1.2)));

  effectAnimators.add((t) async {
    await field.setParameterFloat("time", t);
  });
}
