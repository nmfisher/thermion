import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// UV-aligned XY grid with +Z normals; the materials pin its upper edge and
/// recompute normals from their deformation, including during shadow rendering.
Geometry effectFabricPanel(double width, double height,
    {int nx = 72, int ny = 96}) {
  final positions = <double>[], normals = <double>[], uvs = <double>[];
  final indices = <int>[];
  for (var y = 0; y <= ny; y++) {
    for (var x = 0; x <= nx; x++) {
      final u = x / nx, v = y / ny;
      positions.addAll([(u - .5) * width, v * height, 0]);
      normals.addAll([0, 0, 1]);
      uvs.addAll([u, v]);
      if (x < nx && y < ny) {
        final i = y * (nx + 1) + x;
        indices.addAll([i, i + 1, i + nx + 1, i + 1, i + nx + 2, i + nx + 1]);
      }
    }
  }
  return Geometry(Float32List.fromList(positions), indices,
      normals: Float32List.fromList(normals), uvs: Float32List.fromList(uvs));
}

/// Left to right: teal anisotropic silk, burgundy velvet, and golden woven
/// cloth. Identical drapes and shared lighting make their BRDFs comparable.
Future<void> setupCloth(ThermionViewer viewer,
    {required String assetsDir}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
      near: .1,
      far: 100,
      aspect: viewport.width / viewport.height,
      focalLength: 37);
  await camera.lookAt(Vector3(3.0, 2.8, 11.6), focus: Vector3(0, 1.5, 0));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 8000);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: .02);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);
  await viewer.addDirectLight(DirectLight.sun(
      direction: Vector3(.5, -.45, -.75),
      color: const LinearColor(1, .91, .8),
      intensity: 35000,
      castShadows: true));
  await viewer.addDirectLight(DirectLight.point(
      position: Vector3(3.8, 2.7, 2.5),
      color: const LinearColor(.65, .8, 1),
      intensity: 35000,
      falloffRadius: 12));

  final plinth = await viewer.app.createUbershaderMaterial();
  await plinth.setBaseColorFactor(.025, .03, .04, 1);
  await plinth.setMetallicFactor(.45);
  await plinth.setRoughnessFactor(.32);
  final floor = await effectBox(viewer, Vector3(0, -.08, 0),
      Vector3(7.6, .16, 3.4), plinth.materialInstance);
  await floor.setReceiveShadows(true);
  final rail = await viewer.app.createUbershaderMaterial();
  await rail.setBaseColorFactor(.15, .13, .10, 1);
  await rail.setMetallicFactor(.8);
  await rail.setRoughnessFactor(.23);
  final clothGeometry = effectFabricPanel(1.65, 2.65);
  final fabrics = <MaterialInstance>[];
  for (final spec in <(String, double, Vector3)>[
    ('silk', -2.05, Vector3(.025, .16, .20)),
    ('velvet', 0, Vector3(.07, .004, .012)),
    ('woven_cloth', 2.05, Vector3(.32, .22, .105)),
  ]) {
    final material =
        await loadEffectMaterial(viewer, assetsDir: assetsDir, name: spec.$1);
    await material.setParameterFloat3(
        'fabricColor', spec.$3.x, spec.$3.y, spec.$3.z);
    await material.setParameterFloat2('clothSize', 1.65, 2.65);
    await material.setParameterFloat('time', 1.7);
    await material.setParameterFloat('windSpeed', 1);
    await material.setParameterFloat('windStrength', .65);
    await material.setParameterFloat('weaveScale', 72);
    await material.setParameterFloat('weaveStrength', .65);
    if (spec.$1 == 'silk') {
      await material.setParameterFloat('roughness', .27);
      await material.setParameterFloat('anisotropy', .8);
    } else if (spec.$1 == 'velvet') {
      await material.setParameterFloat3('sheenColor', .65, .075, .14);
      await material.setParameterFloat('sheenStrength', 1);
    }
    final fabric = await viewer
        .createGeometry(clothGeometry, materialInstances: [material]);
    await fabric.setTransform(Matrix4.translation(Vector3(spec.$2, .28, 0)));
    await fabric.setCastShadows(true);
    await fabric.setReceiveShadows(true);
    fabrics.add(material);
    await effectBox(viewer, Vector3(spec.$2, 2.96, 0), Vector3(1.95, .07, .08),
        rail.materialInstance);
    for (final x in [spec.$2 - .93, spec.$2 + .93]) {
      await effectBox(viewer, Vector3(x, 1.5, -.18), Vector3(.035, 3, .035),
          rail.materialInstance);
    }
  }
  Future<void> shared(String name, double value) async {
    for (final fabric in fabrics) {
      await fabric.setParameterFloat(name, value);
    }
  }

  effectSliders.addAll([
    EffectSlider('Wind strength',
        min: 0,
        max: 1.5,
        initialValue: .65,
        setValue: (v) => shared('windStrength', v)),
    EffectSlider('Wind speed',
        min: 0,
        max: 2.5,
        initialValue: 1,
        setValue: (v) => shared('windSpeed', v)),
    EffectSlider('Thread count',
        min: 24,
        max: 160,
        step: 1,
        initialValue: 72,
        setValue: (v) => shared('weaveScale', v)),
    EffectSlider('Thread relief',
        min: 0,
        max: 1,
        initialValue: .65,
        setValue: (v) => shared('weaveStrength', v)),
    EffectSlider('Silk roughness', min: .12, max: .65, initialValue: .27,
        setValue: (v) async {
      await fabrics[0].setParameterFloat('roughness', v);
    }),
    EffectSlider('Silk anisotropy', min: 0, max: .95, initialValue: .8,
        setValue: (v) async {
      await fabrics[0].setParameterFloat('anisotropy', v);
    }),
    EffectSlider('Velvet sheen', min: 0, max: 1.5, initialValue: 1,
        setValue: (v) async {
      await fabrics[1].setParameterFloat('sheenStrength', v);
    }),
  ]);
  effectAnimators.add((t) => shared('time', t));
}
