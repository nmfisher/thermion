import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

Future<void> setupTornado(ThermionViewer viewer, {required String assetsDir}) =>
    _setupStorm(viewer, assetsDir: assetsDir, sandstorm: false);

Future<void> setupSandstorm(ThermionViewer viewer,
        {required String assetsDir}) =>
    _setupStorm(viewer, assetsDir: assetsDir, sandstorm: true);

/// Bounded procedural dust with a helical funnel or a broad wind-driven wall.
/// Debris is generated on the GPU; no particle-system or engine API is required.
Future<void> _setupStorm(
  ThermionViewer viewer, {
  required String assetsDir,
  required bool sandstorm,
}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
      near: .1,
      far: 100,
      aspect: viewport.width / viewport.height,
      focalLength: 32);
  await camera.lookAt(
      sandstorm ? Vector3(5.6, 1.95, 10.2) : Vector3(6.8, 2.35, 9.2),
      focus: Vector3(sandstorm ? -.6 : 0, sandstorm ? 1.85 : 2.35, sandstorm ? -.8 : 0));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx',
      intensity: sandstorm ? 5000 : 2500);
  await (await viewer.view.getScene()).setSkybox(await viewer.app
      .createColoredSkybox(
          r: sandstorm ? .052 : .009,
          g: sandstorm ? .030 : .014,
          b: sandstorm ? .013 : .022,
          a: 1));
  await enableVfxPost(viewer, bloomStrength: .035);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.addDirectLight(DirectLight.sun(
      direction: Vector3(-.6, -.7, -.25),
      color: sandstorm
          ? const LinearColor(1, .8, .55)
          : const LinearColor(.75, .85, 1),
      intensity: 22000,
      castShadows: false));

  final ground = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'storm_ground');
  final groundColor =
      sandstorm ? Vector3(.29, .16, .065) : Vector3(.055, .062, .068);
  await ground.setParameterFloat3(
      'sandColor', groundColor.x, groundColor.y, groundColor.z);
  final floor = await viewer.createGeometry(
      GeometryUtils.plane(width: sandstorm ? 34 : 26, height: sandstorm ? 28 : 24),
      materialInstances: [ground]);
  await floor.setTransform(Matrix4.translation(Vector3(0, -.025, 0)));

  final dust = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'storm_volume');
  final debris = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'storm_debris');
  final width = sandstorm ? 22.0 : 8.6;
  final depth = sandstorm ? 14.0 : 8.6;
  final height = sandstorm ? 6.8 : 5.8;
  for (final instance in [dust, debris]) {
    await instance.setParameterFloat('time', 2.6);
    await instance.setParameterFloat('windSpeed', 1);
    await instance.setParameterFloat('density', sandstorm ? 1.8 : 2.2);
    await instance.setParameterFloat('funnelWidth', 1);
    await instance.setParameterFloat('stormType', sandstorm ? 1 : 0);
  }
  await dust.setParameterFloat('turbulence', 1);
  await dust.setParameterFloat3('volumeMin', -width / 2, 0, -depth / 2);
  await dust.setParameterFloat3('volumeMax', width / 2, height, depth / 2);
  final dustColor = sandstorm ? Vector3(.47, .28, .12) : Vector3(.29, .32, .36);
  await dust.setParameterFloat3(
      'dustColor', dustColor.x, dustColor.y, dustColor.z);
  await debris.setParameterFloat('debrisAmount', .75);
  final volume = await effectBox(
      viewer, Vector3(0, height / 2, 0), Vector3(width, height, depth), dust);
  final particles = await viewer
      .createGeometry(dummyBillboardQuads(256), materialInstances: [debris]);
  // Debris is an artistic overlay, consistently drawn after the dust volume.
  await viewer.app.renderableManager.setPriority(volume.entity, 4);
  await viewer.app.renderableManager.setPriority(particles.entity, 5);

  Future<void> shared(String name, double value) async {
    for (final instance in [dust, debris]) {
      await instance.setParameterFloat(name, value);
    }
  }

  effectSliders.addAll([
    EffectSlider('Wind speed',
        min: 0,
        max: 2.5,
        initialValue: 1,
        setValue: (v) => shared('windSpeed', v)),
    EffectSlider('Dust density',
        min: 0,
        max: 4,
        initialValue: sandstorm ? 1.8 : 2.2,
        setValue: (v) => shared('density', v)),
    EffectSlider('Turbulence', min: 0, max: 2, initialValue: 1,
        setValue: (v) async {
      await dust.setParameterFloat('turbulence', v);
    }),
    EffectSlider('Debris amount', min: 0, max: 1, initialValue: .75,
        setValue: (v) async {
      await debris.setParameterFloat('debrisAmount', v);
    }),
    if (!sandstorm)
      EffectSlider('Funnel width',
          min: .5,
          max: 1.4,
          initialValue: 1,
          setValue: (v) => shared('funnelWidth', v)),
  ]);
  effectAnimators.add((t) => shared('time', t));
}
