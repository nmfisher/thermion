import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// A segmented sentinel transfers between two pads. Surface samples travel
/// between corresponding points, instead of unrelated spark positions.
Future<void> setupTeleportation(ThermionViewer viewer,
    {required String assetsDir}) async {
  await setupInteractionStage(
      viewer, assetsDir, Vector3(3.2, 2.8, 7.6), Vector3(0, 1.0, 0),
      shadows: false);
  await viewer.view.setFrustumCullingEnabled(false);
  final ground = await viewer.app.createUbershaderMaterial();
  await ground.setBaseColorFactor(.018, .026, .035, 1);
  await ground.setRoughnessFactor(.85);
  await viewer.createGeometry(GeometryUtils.plane(width: 40, height: 40),
      materialInstances: [ground.materialInstance]);
  final source = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'teleport_surface');
  final target = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'teleport_surface');
  await source.setParameterFloat('origin', -1.45);
  await target.setParameterFloat('origin', 1.45);
  await source.setParameterFloat('reassemble', 0);
  await target.setParameterFloat('reassemble', 1);
  // Center, dimensions: feet, legs, pelvis, torso, arms, neck, head.
  final parts = <(Vector3, Vector3)>[
    (Vector3(-.19, .11, .06), Vector3(.25, .16, .42)),
    (Vector3(.19, .11, .06), Vector3(.25, .16, .42)),
    (Vector3(-.19, .53, 0), Vector3(.23, .72, .26)),
    (Vector3(.19, .53, 0), Vector3(.23, .72, .26)),
    (Vector3(0, .98, 0), Vector3(.6, .25, .32)),
    (Vector3(0, 1.38, 0), Vector3(.68, .62, .36)),
    (Vector3(-.47, 1.31, 0), Vector3(.2, .74, .24)),
    (Vector3(.47, 1.31, 0), Vector3(.2, .74, .24)),
    (Vector3(0, 1.77, 0), Vector3(.17, .16, .18)),
    (Vector3(0, 2.0, 0), Vector3(.37, .36, .32)),
  ];
  for (final (offset, material) in [(-1.45, source), (1.45, target)]) {
    for (final (center, size) in parts) {
      if (center.y > 1.9) {
        final helmet = await viewer.createGeometry(
            GeometryUtils.sphere(latitudeBands: 20, longitudeBands: 24),
            materialInstances: [material]);
        await helmet.setTransform(
            Matrix4.translation(center + Vector3(offset, 0, 0)) *
                Matrix4.diagonal3(size * .5));
      } else {
        await effectBox(viewer, center + Vector3(offset, 0, 0), size, material);
      }
    }
  }
  final random = math.Random(718);
  final vertices = <double>[];
  // Stratified samples on the actual box surfaces, reused at both endpoints.
  for (final (center, size) in parts) {
    for (var i = 0; i < 80; i++) {
      final p = Vector3(random.nextDouble() - .5, random.nextDouble() - .5,
          random.nextDouble() - .5);
      p[i % 3] = i.isEven ? -.5 : .5;
      if (center.y > 1.9) {
        p.normalize();
        p.scale(.5);
      }
      final point = center + Vector3(p.x * size.x, p.y * size.y, p.z * size.z);
      for (var k = 0; k < 6; k++) {
        vertices.addAll([point.x, point.y, point.z]);
      }
    }
  }
  final particles = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'teleport_particles');
  final motes = await viewer.createGeometry(
      Geometry(Float32List.fromList(vertices),
          List<int>.generate(vertices.length ~/ 3, (i) => i)),
      materialInstances: [particles]);
  await motes.setCastShadows(false);
  final fields = <MaterialInstance>[];
  for (final x in [-1.45, 1.45]) {
    final field = await loadEffectMaterial(viewer,
        assetsDir: assetsDir, name: 'teleport_field');
    fields.add(field);
    final pad = await viewer.createGeometry(
        GeometryUtils.plane(width: 1.8, height: 1.8),
        materialInstances: [field]);
    await pad.setTransform(Matrix4.translation(Vector3(x, .018, 0)));
    await pad.setCastShadows(false);
  }
  final light = await viewer.addDirectLight(DirectLight.point(
      color: const LinearColor(.08, .4, 1),
      intensity: 0,
      position: Vector3(0, 1.5, .5),
      falloffRadius: 4));
  Future<void> animate(double t) async {
    final cycle = t % 6;
    final reset = effectEase(5.35, 5.95, cycle);
    await source.setParameterFloat(
        'dissolve', -.1 + 1.25 * effectEase(.8, 1.65, cycle) * (1 - reset));
    await target.setParameterFloat(
        'dissolve', 1.15 - 1.25 * effectEase(2.15, 3.1, cycle) * (1 - reset));
    await particles.setParameterFloat(
        'travel', ((cycle - .85) / 2.15).clamp(0.0, 1.0));
    for (var i = 0; i < fields.length; i++) {
      await fields[i].setParameterFloat('time', t);
      final pulse =
          math.exp(-math.pow((cycle - (i == 0 ? 1.25 : 2.6)) / .55, 2));
      await fields[i].setParameterFloat('strength', .24 + pulse * .76);
    }
    viewer.app.lightManager.setIntensity(light,
        14000 * effectEase(.6, 1.2, cycle) * (1 - effectEase(2.8, 3.4, cycle)));
  }

  await animate(2.65);
  effectAnimators.add(animate);
}
