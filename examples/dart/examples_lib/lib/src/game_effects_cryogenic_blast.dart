import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Radially propagating frost, staggered crystal growth, airborne ice chips,
/// and drifting cold vapor. A six-second cycle resets only after fading out.
Future<void> setupCryogenicBlast(ThermionViewer viewer,
    {required String assetsDir}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
      near: .1, far: 100, aspect: 1, focalLength: 35);
  await camera.lookAt(Vector3(4.1, 3.6, 5.8), focus: Vector3(0, .35, 0));
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: .16);
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 1600);
  await viewer.addDirectLight(
      DirectLight.sun(direction: Vector3(-.5, -.8, -.3), intensity: 16000));
  final light = await viewer.addDirectLight(DirectLight.point(
      color: const LinearColor(.12, .55, 1),
      intensity: 0,
      falloffRadius: 4,
      position: Vector3(0, .6, .4)));
  final ground = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'cryogenic_ground');
  await viewer.createGeometry(GeometryUtils.plane(width: 40, height: 40),
      materialInstances: [ground]);
  final ice = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'crystal_ice');
  await ice.setParameterFloat4('tint', .075, .5, .8, 1);
  final vapor = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'cryogenic_vapor');
  final grow = <Future<void> Function(double, double)>[];
  double ease(double a, double b, double x) {
    final u = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  for (var i = 0; i < 27; i++) {
    final a = i * 2.39996;
    final r = i == 0 ? 0.0 : .28 + math.sqrt(i / 26) * 1.4;
    final height = i == 0 ? 1.65 : .25 + (1 - r / 2) * (.5 + (i % 5) * .22);
    final shard = await viewer.createGeometry(
        crystalShard(radius: .12 + (i % 3) * .035, length: height),
        materialInstances: [ice]);
    grow.add((cycle, fade) async {
      final size =
          math.max(.001, ease(.55 + r * .45, 1.1 + r * .45, cycle) * fade);
      await shard.setTransform(Matrix4.translation(
              Vector3(math.cos(a) * r, -.025, math.sin(a) * r)) *
          Matrix4.rotationY(-a) *
          Matrix4.rotationZ(-r * .25) *
          Matrix4.diagonal3(Vector3(size, size, size)));
    });
  }
  for (var i = 0; i < 12; i++) {
    final a = i * 2.39996;
    final chip = await viewer.createGeometry(
        crystalShard(radius: .025, length: .13),
        materialInstances: [ice]);
    grow.add((cycle, fade) async {
      final age = (cycle - .9 - (i % 4) * .08).clamp(0.0, 4.0);
      final height = math.max(0.0, 1.9 * age - 1.2 * age * age);
      final visible = ease(0, .08, age) * (1 - ease(1.2, 1.6, age)) * fade;
      final r = .3 + age * (.7 + (i % 3) * .22);
      await chip.setTransform(Matrix4.translation(
              Vector3(math.cos(a) * r, .25 + height, math.sin(a) * r)) *
          Matrix4.rotationZ(a + age * 5) *
          Matrix4.diagonal3(Vector3.all(math.max(.001, visible))));
    });
  }
  final clouds = <Future<void> Function(double)>[];
  for (var i = 0; i < 8; i++) {
    final cloud = await viewer.createGeometry(
        GeometryUtils.plane(width: 2.5, height: 1.6),
        materialInstances: [vapor]);
    // A translucent vapor card must not cast its rectangular mesh shadow.
    await cloud.setCastShadows(false);
    clouds.add((cycle) async {
      final a = i * math.pi / 4;
      final drift = .35 + (cycle / 6) * 1.4;
      await cloud.setTransform(Matrix4.translation(Vector3(
              math.cos(a) * drift, .22 + (i % 3) * .12, math.sin(a) * drift)) *
          Matrix4.rotationY(.616) *
          Matrix4.rotationX(math.pi / 2));
    });
  }
  Future<void> animate(double t) async {
    final cycle = t % 6;
    final fade = 1 - ease(4.3, 5.8, cycle);
    await ground.setParameterFloat('radius', ease(.25, 2.3, cycle) * 2.3);
    await ground.setParameterFloat('strength', fade);
    await ice.setParameterFloat('time', t);
    await vapor.setParameterFloat('time', t);
    await vapor.setParameterFloat('strength', ease(.6, 1.4, cycle) * fade);
    viewer.app.lightManager
        .setIntensity(light, 9000 * ease(.3, .8, cycle) * fade);
    for (final update in grow) {
      await update(cycle, fade);
    }
    for (final update in clouds) {
      await update(cycle);
    }
  }

  await animate(2.2);
  effectAnimators.add(animate);
}
