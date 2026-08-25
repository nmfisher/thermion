import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Shockwave: an energy pulse every [period] seconds - an arc-broken ring
/// races out across the ground plane while a fresnel dome expands out of
/// the epicenter and fades. The dome's scale is driven from Dart (the
/// animator), its fade from the material's `age` uniform.
Future<void> setupShockwave(
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
  await camera.lookAt(Vector3(0, 2.6, 5.2), focus: Vector3(0, 0.3, 0));

  await setDarkSkybox(viewer);

  const period = 2.2;
  const waveSpeed = 3.6;

  final ground = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "shockwave_ground",
  );
  await ground.setParameterFloat("time", 0.0);
  await ground.setParameterFloat("period", period);
  await ground.setParameterFloat("waveSpeed", waveSpeed);

  final groundPlane = await viewer.createGeometry(
    subdividedPlane(width: 18.0, depth: 18.0, subdivisionsX: 4, subdivisionsZ: 4),
    materialInstances: [ground],
  );
  await groundPlane.setTransform(Matrix4.translation(Vector3(0, 0, 0)));

  final dome = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "shockwave_dome",
  );
  await dome.setParameterFloat4("baseColor", 0.30, 0.75, 1.0, 1.0);
  await dome.setParameterFloat("time", 0.0);
  await dome.setParameterFloat("age", 0.0);

  final domeSphere = await viewer.createGeometry(
    GeometryUtils.sphere(latitudeBands: 32, longitudeBands: 48),
    materialInstances: [dome],
  );

  effectAnimators.add((t) async {
    final age = t % period;
    await ground.setParameterFloat("time", t);
    await dome.setParameterFloat("time", t);
    await dome.setParameterFloat("age", age);
    // The dome expands with the ground ring's front and dissolves.
    final radius = 0.15 + age * waveSpeed * 0.78;
    await domeSphere.setTransform(
      Matrix4.identity()..scaleByVector3(Vector3.all(radius)),
    );
  });
}
