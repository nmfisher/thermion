import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Art-directed lensing against a procedural starfield, not a scene-color
/// refraction pass. The disk and stars are rendered together so the horizon
/// really occludes the background instead of adding black onto it.
Future<void> setupBlackHole(ThermionViewer viewer,
    {required String assetsDir}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
      near: .1, far: 100, aspect: 1, focalLength: 35);
  await camera.lookAt(Vector3(0, 0, 7.8), focus: Vector3.zero());
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: .18);
  final material = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'black_hole');
  final field = await viewer.createGeometry(
      GeometryUtils.plane(width: 9, height: 9),
      materialInstances: [material]);
  await field.setTransform(Matrix4.rotationX(math.pi / 2));
  final debrisMaterial = await viewer.app.createUbershaderMaterial(unlit: true);
  await debrisMaterial.setBaseColorFactor(.006, .003, .002, 1);
  final orbiters = <Future<void> Function(double)>[];
  for (var i = 0; i < 24; i++) {
    final seed = i.toDouble();
    final debris = await viewer.createGeometry(
        crystalShard(radius: .02, length: .06),
        materialInstances: [debrisMaterial.materialInstance]);
    orbiters.add((t) async {
      final a = seed * 2.39996 + t * (.11 + (i % 5) * .018);
      final r = 2.4 + (i % 4) * .12;
      await debris.setTransform(Matrix4.translation(
              Vector3(math.cos(a) * r, math.sin(a) * r * .37, .05)) *
          Matrix4.rotationZ(a + t * .2) *
          Matrix4.rotationY(seed));
    });
  }
  Future<void> animate(double t) async {
    await material.setParameterFloat('time', t);
    for (final orbit in orbiters) {
      await orbit(t);
    }
  }

  await animate(1.5);
  effectAnimators.add(animate);
}
