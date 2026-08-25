import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Coordinated energy-weapon suite: pre-charge orb, turbulent beam envelope,
/// traveling core pulses, muzzle bloom, and a delayed expanding impact shell.
Future<void> setupEnergyWeapon(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: 1,
    focalLength: 38,
  );
  await camera.lookAt(Vector3(0, 0.15, 5.3), focus: Vector3(0, 0, 0));
  await viewer.view.setFrustumCullingEnabled(false);
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx');
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.65);

  final beam = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'energy_weapon',
  );
  await beam.setParameterFloat('time', 1.2);
  await beam.setParameterFloat('mode', 0.0);
  await beam.setParameterFloat('phase', 0.8);
  final beamEntity = await viewer.createGeometry(
    GeometryUtils.plane(width: 4.7, height: 1.35),
    materialInstances: [beam],
  );
  await beamEntity.setTransform(
    Matrix4.translation(Vector3(0, 0, 0)) *
        Matrix4.rotationX(1.5707963267948966),
  );
  effectAnimators.add((t) async {
    final cycle = t % 2.6;
    final fire = cycle > 0.58 && cycle < 1.38
        ? math.sin((cycle - 0.58) / 0.8 * math.pi)
        : 0.0;
    await beam.setParameterFloat('time', t);
    await beam.setParameterFloat('phase', fire);
  });
}
