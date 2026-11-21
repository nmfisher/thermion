import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// A plasma lance between a machined emitter and an armored target.
/// The shader, local lights, and emitter illumination share a deterministic
/// charge / sustained discharge / cooldown timeline.
Future<void> setupEnergyWeapon(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
      near: 0.1, far: 100, aspect: 1, focalLength: 38);
  await camera.lookAt(Vector3(0, 1.5, 8.2), focus: Vector3(0, -.12, 0));
  await viewer.view.setFrustumCullingEnabled(false);
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 1200);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: .22);
  await viewer.setShadowsEnabled(true);

  final metal = await viewer.app.createUbershaderMaterial();
  await metal.setBaseColorFactor(.065, .085, .12, 1);
  await metal.setMetallicFactor(.8);
  await metal.setRoughnessFactor(.32);
  final armor = await viewer.app.createUbershaderMaterial();
  await armor.setBaseColorFactor(.11, .13, .17, 1);
  await armor.setMetallicFactor(.65);
  await armor.setRoughnessFactor(.43);
  final dark = await viewer.app.createUbershaderMaterial();
  await dark.setBaseColorFactor(.009, .014, .024, 1);
  await dark.setMetallicFactor(.35);
  await dark.setRoughnessFactor(.38);
  final floor = await viewer.app.createUbershaderMaterial();
  await floor.setBaseColorFactor(.012, .016, .024, 1);
  await floor.setMetallicFactor(0);
  await floor.setRoughnessFactor(1);
  final illuminated = await viewer.app.createUbershaderMaterial();
  await illuminated.setBaseColorFactor(.01, .12, .3, 1);
  await illuminated.setEmissiveFactor(.025, .35, 1.0, .5);

  Future<void> block(
      Vector3 position, Vector3 size, MaterialInstance material) async {
    final entity = await viewer.createGeometry(
      GeometryUtils.cube(),
      materialInstances: [material],
    );
    await entity.setTransform(
        Matrix4.translation(position) * Matrix4.diagonal3(size * .5));
  }

  Future<void> barrel(
      double x, double radius, double length, MaterialInstance material) async {
    final entity = await viewer.createGeometry(
      GeometryUtils.cylinder(radius: radius, length: length, uvs: false),
      materialInstances: [material],
    );
    await entity.setTransform(Matrix4.translation(Vector3(x, 0, .3)) *
        Matrix4.rotationZ(math.pi / 2));
  }

  await barrel(-2.05, .23, .52, metal.materialInstance);
  await barrel(-2.32, .19, .04, dark.materialInstance);
  for (var i = 0; i < 4; i++) {
    await barrel(-2.23 + i * .09, .25, .022, dark.materialInstance);
  }
  await barrel(-1.76, .2, .35, dark.materialInstance);
  await barrel(-1.59, .145, .08, metal.materialInstance);
  for (var i = 0; i < 3; i++) {
    await barrel(-1.93 + i * .105, .214, .028, illuminated.materialInstance);
  }
  await block(Vector3(-2.02, -.51, .22), Vector3(.22, .58, .25),
      metal.materialInstance);
  await block(
      Vector3(-2.0, -.79, .25), Vector3(.9, .12, .85), dark.materialInstance);

  // The target starts precisely where the lance terminates, with the
  // luminous impact plane just ahead of its visible face.
  await block(
      Vector3(1.85, 0, .0), Vector3(.6, 1.3, .58), armor.materialInstance);
  await block(
      Vector3(1.88, -.79, .02), Vector3(.94, .12, .95), dark.materialInstance);
  for (var i = 0; i < 4; i++) {
    await block(Vector3(1.86, -.49 + i * .32, .3), Vector3(.51, .025, .025),
        dark.materialInstance);
  }
  await block(Vector3(0, -.9, 0), Vector3(12, .1, 8), floor.materialInstance);
  await viewer.addDirectLight(DirectLight.sun(
    direction: Vector3(-.3, -.8, -.6),
    intensity: 9000,
    castShadows: true,
  ));
  final muzzleLight = await viewer.addDirectLight(DirectLight.point(
    color: const LinearColor(.06, .4, 1),
    intensity: 0,
    falloffRadius: 2.5,
    position: Vector3(-1.45, .1, .55),
    castShadows: false,
  ));
  final impactLight = await viewer.addDirectLight(DirectLight.point(
    color: const LinearColor(.25, .65, 1),
    intensity: 0,
    falloffRadius: 2.5,
    position: Vector3(1.45, .1, .7),
    castShadows: false,
  ));

  final beam = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'energy_weapon');
  await beam.setParameterFloat('mode', 0);
  final beamEntity = await viewer.createGeometry(
    GeometryUtils.plane(width: 4.7, height: 2.1),
    materialInstances: [beam],
  );
  await beamEntity.setTransform(
      Matrix4.translation(Vector3(0, 0, .34)) * Matrix4.rotationX(math.pi / 2));

  double ease(double a, double b, double x) {
    final u = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  Future<void> animate(double t) async {
    final cycle = t % 3.6;
    final fire = ease(.72, .82, cycle) * (1 - ease(2.05, 2.4, cycle));
    final charge = ease(.15, .72, cycle) * (1 - ease(.78, 1.05, cycle));
    await beam.setParameterFloat('time', t);
    await beam.setParameterFloat('phase', fire);
    viewer.app.lightManager
        .setIntensity(muzzleLight, 3500 * charge + 6500 * fire);
    viewer.app.lightManager.setIntensity(impactLight, 11000 * fire);
    await illuminated.setEmissiveFactor(
        .025, .35, 1.0, .12 + charge * .6 + fire * .9);
  }

  await animate(1.2);
  effectAnimators.add(animate);
}
