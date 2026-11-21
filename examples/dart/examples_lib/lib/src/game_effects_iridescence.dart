import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Coated metal (left), pearl (center), soap bubble (right), and a dark oil
/// film (foreground) under the same studio environment and direct lights.
Future<void> setupIridescence(ThermionViewer viewer,
    {required String assetsDir}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
      near: .1,
      far: 100,
      aspect: viewport.width / viewport.height,
      focalLength: 40);
  await camera.lookAt(Vector3(3.3, 3.6, 12.5), focus: Vector3(0, 1.1, .4));
  effectCameraControls = EffectCameraControls(focus: Vector3(0, 1.1, .4));
  await setDarkSkybox(viewer);
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 22000);
  await enableVfxPost(viewer, bloomStrength: .035);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);
  await viewer.addDirectLight(DirectLight.sun(
      direction: Vector3(.4, -.7, -.6), intensity: 38000, castShadows: true));
  await viewer.addDirectLight(DirectLight.point(
      position: Vector3(3.5, 3.5, -2),
      color: const LinearColor(.7, .82, 1),
      intensity: 60000,
      falloffRadius: 15));
  final stand = await viewer.app.createUbershaderMaterial();
  await stand.setBaseColorFactor(.025, .032, .045, 1);
  await stand.setMetallicFactor(.35);
  await stand.setRoughnessFactor(.28);
  final floor = await effectBox(viewer, Vector3(0, -.1, .5),
      Vector3(7.4, .2, 4.7), stand.materialInstance);
  await floor.setReceiveShadows(true);
  final sphere = GeometryUtils.sphere(latitudeBands: 64, longitudeBands: 96);
  final films = <MaterialInstance>[];
  for (final spec in <(double, Vector3, Vector3, String)>[
    (0, Vector3(-2.15, 1.57, 0), Vector3(.8, 1.08, .8), 'iridescent_surface'),
    (1, Vector3(0, 1.3, 0), Vector3.all(.81), 'iridescent_surface'),
    (0, Vector3(2.15, 1.55, 0), Vector3.all(.91), 'iridescent_bubble'),
    (
      2,
      Vector3(.05, .23, 2.05),
      Vector3(1.35, .075, .72),
      'iridescent_surface'
    ),
  ]) {
    final material =
        await loadEffectMaterial(viewer, assetsDir: assetsDir, name: spec.$4);
    await material.setParameterFloat('time', 2.4);
    await material.setParameterFloat('speed', 1);
    await material.setParameterFloat('thickness', 480);
    await material.setParameterFloat('variation', 160);
    await material.setParameterFloat('filmIor', 1.65);
    await material.setParameterFloat('strength', 1);
    await material.setParameterFloat('roughness', .18);
    if (spec.$4 == 'iridescent_surface') {
      await material.setParameterFloat('preset', spec.$1);
    }
    final object =
        await viewer.createGeometry(sphere, materialInstances: [material]);
    await object.setTransform(
        Matrix4.translation(spec.$2) * Matrix4.diagonal3(spec.$3));
    await object.setCastShadows(spec.$4 != 'iridescent_bubble');
    await object.setReceiveShadows(true);
    films.add(material);
    if (spec.$1 != 2) {
      final pedestal = await effectBox(viewer, Vector3(spec.$2.x, .23, 0),
          Vector3(1.85, .46, 1.85), stand.materialInstance);
      await pedestal.setReceiveShadows(true);
    }
  }
  // An opaque striped card behind the bubble makes transmission visible.
  final backdrop = await viewer.app.createUbershaderMaterial();
  await backdrop.setBaseColorFactor(.055, .075, .11, 1);
  await backdrop.setRoughnessFactor(.7);
  await effectBox(viewer, Vector3(2.15, 1.5, -1.15), Vector3(1.95, 2.4, .08),
      backdrop.materialInstance);
  for (var i = 0; i < 5; i++) {
    await effectBox(viewer, Vector3(1.35 + i * .4, 1.5, -1.09),
        Vector3(.055, 2.4, .03), stand.materialInstance);
  }
  Future<void> shared(String name, double value) async {
    for (final material in films) {
      await material.setParameterFloat(name, value);
    }
  }

  effectSliders.addAll([
    EffectSlider('Film thickness (nm)',
        min: 0,
        max: 1200,
        step: 1,
        initialValue: 480,
        setValue: (v) => shared('thickness', v)),
    EffectSlider('Thickness variation',
        min: 0,
        max: 400,
        step: 1,
        initialValue: 160,
        setValue: (v) => shared('variation', v)),
    EffectSlider('Film refractive index',
        min: 1.05,
        max: 2.4,
        initialValue: 1.65,
        setValue: (v) => shared('filmIor', v)),
    EffectSlider('Iridescence',
        min: 0,
        max: 1,
        initialValue: 1,
        setValue: (v) => shared('strength', v)),
    EffectSlider('Roughness',
        min: .06,
        max: .65,
        initialValue: .18,
        setValue: (v) => shared('roughness', v)),
    EffectSlider('Flow speed',
        min: 0, max: 3, initialValue: 1, setValue: (v) => shared('speed', v)),
  ]);
  effectAnimators.add((t) => shared('time', t));
}
