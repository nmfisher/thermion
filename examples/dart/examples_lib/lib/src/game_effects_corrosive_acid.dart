import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Reactive acid pool with timed bubble pops/ripples, droplets, vapor, and
/// a pitted metal specimen. Contact is art-directed, not a corrosion solver.
Future<void> setupCorrosiveAcid(ThermionViewer viewer,
    {required String assetsDir}) async {
  await setupInteractionStage(
      viewer, assetsDir, Vector3(3.6, 3.4, 4.7), Vector3(0, .3, 0));
  final pool = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'corrosive_acid');
  await pool.setParameterFloat('mode', 0);
  await viewer.createGeometry(GeometryUtils.plane(width: 40, height: 40),
      materialInstances: [pool]);
  final metal = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'corrosive_acid');
  await metal.setParameterFloat('mode', 1);
  final plate = await viewer
      .createGeometry(GeometryUtils.cube(), materialInstances: [metal]);
  await plate.setTransform(Matrix4.translation(Vector3(.15, .63, -.18)) *
      Matrix4.rotationZ(-.22) *
      Matrix4.diagonal3(Vector3(.48, .82, .095)));
  final rib = await viewer
      .createGeometry(GeometryUtils.cube(), materialInstances: [metal]);
  await rib.setTransform(Matrix4.translation(Vector3(-.45, .3, -.15)) *
      Matrix4.rotationZ(.6) *
      Matrix4.diagonal3(Vector3(.11, .52, .13)));
  final bubble = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'acid_bubble');
  final drops = await viewer.app.createUbershaderMaterial();
  await drops.setBaseColorFactor(.055, .13, .006, 1);
  await drops.setRoughnessFactor(.13);
  await drops.setEmissiveFactor(.03, .1, .001, .1);
  final animateBubbles = <Future<void> Function(double)>[];
  for (var i = 0; i < 16; i++) {
    final shell = await viewer.createGeometry(
        GeometryUtils.sphere(latitudeBands: 16, longitudeBands: 24),
        materialInstances: [bubble]);
    await shell.setCastShadows(false);
    final droplet = await viewer.createGeometry(
        GeometryUtils.sphere(latitudeBands: 8, longitudeBands: 12),
        materialInstances: [drops.materialInstance]);
    final angle = i * 2.39996, radius = .3 + (i % 7) * .14;
    final x = math.cos(angle) * radius, z = math.sin(angle) * radius;
    animateBubbles.add((t) async {
      final age = (t * .65 + i * .137) % 1;
      final size = (.07 + (i % 4) * .027) *
          effectEase(0, .7, age) *
          (1 - effectEase(.7, .76, age));
      await shell.setTransform(Matrix4.translation(Vector3(x, -.015, z)) *
          Matrix4.diagonal3(Vector3.all(math.max(.001, size))));
      final flight = ((age - .72) / .28).clamp(0.0, 1.0);
      final s = math.max(.001, .025 * math.sin(flight * math.pi));
      await droplet.setTransform(Matrix4.translation(Vector3(
              x + math.cos(angle) * flight * .17,
              .035 + math.sin(flight * math.pi) * .45,
              z + math.sin(angle) * flight * .17)) *
          Matrix4.diagonal3(Vector3(s, s * 1.65, s)));
    });
  }
  final vapor = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'interaction_vapor');
  await vapor.setParameterFloat4('tint', .065, .12, .026, .2);
  for (var i = 0; i < 4; i++) {
    final puff = await viewer.createGeometry(
        GeometryUtils.plane(width: 2.5, height: 2),
        materialInstances: [vapor]);
    await puff.setCastShadows(false);
    await puff.setTransform(Matrix4.translation(
            Vector3((i - 1.5) * .45, .35 + (i % 2) * .18, -.1)) *
        Matrix4.rotationY(.65) *
        Matrix4.rotationX(math.pi / 2));
  }
  await viewer.addDirectLight(DirectLight.point(
      color: const LinearColor(.38, 1, .05),
      intensity: 7000,
      falloffRadius: 3,
      position: Vector3(0, .3, .5)));
  Future<void> animate(double t) async {
    await pool.setParameterFloat('time', t);
    await metal.setParameterFloat('time', t);
    await vapor.setParameterFloat('time', t);
    for (final update in animateBubbles) {
      await update(t);
    }
  }

  await animate(2.2);
  effectAnimators.add(animate);
}
