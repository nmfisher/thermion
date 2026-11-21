import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Bounded, animated single-scattering fog lit through three high windows.
/// Each opaque receiver integrates fog only as far as its visible surface,
/// avoiding the wall/prop bleed of a transparent volume proxy without a depth
/// texture. The same receiver material must be used on added opaque geometry.
Future<void> setupFogLightShafts(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
      near: .1,
      far: 100,
      aspect: viewport.width / viewport.height,
      focalLength: 28);
  await camera.lookAt(Vector3(6.7, 3.5, 8.8), focus: Vector3(0, 1.15, -.2));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 1800);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: .12);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);
  final lightDirection = Vector3(.38, -.48, .78)..normalize();
  await viewer.addDirectLight(DirectLight.sun(
      direction: lightDirection, intensity: 45000, castShadows: true));

  final bytes =
      await viewer.app.loadResource('$assetsDir/fog_light_shafts.filamat');
  final material = await viewer.app.createMaterial(bytes);
  final instances = <MaterialInstance>[];
  Future<MaterialInstance> receiver(Vector3 color, {double glow = 0}) async {
    final instance = await material.createInstance();
    await instance.setParameterFloat4(
        'baseColor', color.x, color.y, color.z, 1);
    await instance.setParameterFloat('sourceGlow', glow);
    await instance.setParameterFloat('time', 1.8);
    await instance.setParameterFloat('density', .24);
    await instance.setParameterFloat('shaftStrength', .55);
    await instance.setParameterFloat('driftSpeed', 1);
    await instance.setParameterFloat3('volumeMin', -3.5, 0, -3);
    await instance.setParameterFloat3('volumeMax', 3.5, 3.8, 3.5);
    await instance.setParameterFloat3(
        'lightDirection', lightDirection.x, lightDirection.y, lightDirection.z);
    await instance.setParameterFloat3('fogColor', .025, .045, .065);
    await instance.setParameterFloat3('lightColor', 1, .74, .42);
    await instance.setParameterFloat3('occluderMin', .65, 0, -1.2);
    await instance.setParameterFloat3('occluderMax', 1.25, 2, -.6);
    instances.add(instance);
    return instance;
  }

  final stone = await receiver(Vector3(.24, .28, .30));
  final trim = await receiver(Vector3(.09, .11, .13));
  final floor = await receiver(Vector3(.19, .21, .22));
  final source = await receiver(Vector3.zero(), glow: 2.0);
  Future<ThermionAsset> box(
      Vector3 center, Vector3 size, MaterialInstance instance) async {
    final asset = await effectBox(viewer, center, size, instance);
    await asset.setCastShadows(true);
    await asset.setReceiveShadows(true);
    return asset;
  }

  await box(Vector3(0, -.12, .25), Vector3(7.3, .24, 6.7), floor);
  await box(Vector3(-3.6, 1.9, .25), Vector3(.2, 3.8, 6.7), stone);
  // Open front and right side keep the room and shafts visible as a diorama.
  await box(Vector3(0, .86, -3.1), Vector3(7.2, 1.72, .2), stone);
  await box(Vector3(0, 3.57, -3.1), Vector3(7.2, .46, .2), stone);
  for (final span in <(double, double)>[
    (-3.5, -2.45),
    (-1.55, -.45),
    (.45, 1.55),
    (2.45, 3.5)
  ]) {
    await box(Vector3((span.$1 + span.$2) / 2, 2.53, -3.1),
        Vector3(span.$2 - span.$1, 1.62, .2), stone);
  }
  for (final x in [-2.0, 0.0, 2.0]) {
    final window =
        await box(Vector3(x, 2.53, -3.32), Vector3(.90, 1.62, .04), source);
    await window.setCastShadows(false);
    await box(Vector3(x, 1.71, -2.94), Vector3(1.08, .08, .35), trim);
  }
  await box(Vector3(.95, 1, -.9), Vector3(.6, 2, .6), stone);
  await box(Vector3(.95, .08, -.9), Vector3(.85, .16, .85), trim);
  // Floor joints and step edges give the drifting ground fog a depth reference.
  for (var z = -2.0; z <= 3; z += 1) {
    await box(Vector3(0, .004, z), Vector3(7, .008, .018), trim);
  }
  for (var x = -3.0; x <= 3; x += 1) {
    await box(Vector3(x, .004, .25), Vector3(.018, .008, 6.5), trim);
  }

  Future<void> update(String name, double value) async {
    for (final instance in instances) {
      await instance.setParameterFloat(name, value);
    }
  }

  for (final spec in <(String, String, double, double, double)>[
    ('Fog density', 'density', 0, .8, .24),
    ('Shaft strength', 'shaftStrength', 0, 5, .55),
    ('Drift speed', 'driftSpeed', 0, 3, 1),
  ]) {
    effectSliders.add(EffectSlider(spec.$1,
        min: spec.$3,
        max: spec.$4,
        initialValue: spec.$5,
        setValue: (value) => update(spec.$2, value)));
  }
  effectAnimators.add((t) => update('time', t));
}
