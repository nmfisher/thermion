import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Closed lathed nozzle with separate inner and outer walls, along X.
Geometry _nozzle() {
  const profile = [
    (-2.5, .24),
    (-2.13, .24),
    (-1.52, .36),
    (-1.45, .36),
    (-1.45, .29),
    (-1.52, .29),
    (-2.13, .17),
    (-2.5, .17),
  ];
  final positions = <double>[], normals = <double>[];
  final indices = <int>[];
  for (var j = 0; j < profile.length; j++) {
    final a = profile[j], b = profile[(j + 1) % profile.length];
    final dx = b.$1 - a.$1, dr = b.$2 - a.$2;
    final length = math.sqrt(dx * dx + dr * dr);
    final base = positions.length ~/ 3;
    for (var i = 0; i <= 64; i++) {
      final angle = i * math.pi * 2 / 64;
      final c = math.cos(angle), s = math.sin(angle);
      for (final p in [a, b]) {
        positions.addAll([p.$1, p.$2 * c, p.$2 * s]);
        normals.addAll([-dr / length, dx / length * c, dx / length * s]);
      }
      if (i < 64) {
        final k = base + i * 2;
        indices.addAll([k, k + 2, k + 1, k + 1, k + 2, k + 3]);
      }
    }
  }
  return Geometry(Float32List.fromList(positions), indices,
      normals: Float32List.fromList(normals));
}

/// Side-on exhaust study: projected conical shock sheets, flowing gas, and a
/// hollow metal nozzle. All animation is deterministic for capture/replay.
Future<void> setupThruster(ThermionViewer viewer,
    {required String assetsDir}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
      near: .1, far: 100, aspect: 1, focalLength: 35);
  await camera.lookAt(Vector3(-.15, .9, 7.6), focus: Vector3(-.15, 0, 0));
  await (await viewer.view.getScene()).setSkybox(
      await viewer.app.createColoredSkybox(r: .0005, g: .0007, b: .0014, a: 1));
  await enableVfxPost(viewer, bloomStrength: .08);
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 1800);
  final metal = await viewer.app.createUbershaderMaterial(doubleSided: true);
  await metal.setBaseColorFactor(.085, .10, .13, 1);
  await metal.setMetallicFactor(.85);
  await metal.setRoughnessFactor(.28);
  await viewer
      .createGeometry(_nozzle(), materialInstances: [metal.materialInstance]);
  final collar = await viewer.app.createUbershaderMaterial();
  await collar.setBaseColorFactor(.014, .02, .035, 1);
  await collar.setMetallicFactor(.7);
  await collar.setRoughnessFactor(.4);
  for (var i = 0; i < 5; i++) {
    final ring = await viewer.createGeometry(
        GeometryUtils.cylinder(radius: .255, length: .032, uvs: false),
        materialInstances: [collar.materialInstance]);
    await ring.setTransform(
        Matrix4.translation(Vector3(-2.46 + i * .07, 0, 0)) *
            Matrix4.rotationZ(math.pi / 2));
  }
  await viewer.addDirectLight(
      DirectLight.sun(direction: Vector3(-.4, -.6, -.8), intensity: 18000));
  final light = await viewer.addDirectLight(DirectLight.point(
      color: const LinearColor(.15, .35, 1),
      intensity: 18000,
      falloffRadius: 3,
      position: Vector3(-1.3, .1, .4)));
  final exhaust = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'thruster_exhaust');
  final plume = await viewer.createGeometry(
      GeometryUtils.plane(width: 5.8, height: 2.6),
      materialInstances: [exhaust]);
  await plume.setTransform(
      Matrix4.translation(Vector3(0, 0, .02)) * Matrix4.rotationX(math.pi / 2));
  await plume.setCastShadows(false);
  Future<void> animate(double t) async {
    final throttle = .7 + .25 * math.sin(t * math.pi / 3);
    await exhaust.setParameterFloat('time', t);
    await exhaust.setParameterFloat('throttle', throttle);
    viewer.app.lightManager.setIntensity(light, 18000 * throttle);
  }

  await animate(1.5);
  effectAnimators.add(animate);
}
