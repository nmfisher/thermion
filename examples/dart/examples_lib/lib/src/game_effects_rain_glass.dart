import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// A real refractive window: moving droplet lenses and wet trails in front of
/// an opaque night-city backdrop. No scene-color capture or CPU rain simulation.
Future<void> setupRainGlass(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
      near: .1,
      far: 100,
      aspect: viewport.width / viewport.height,
      focalLength: 34);
  await camera.lookAt(Vector3(.18, .06, 4.15), focus: Vector3(0, -.04, 0));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 12000);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: .14);
  await viewer.setAntiAliasing(false, true, false);

  Geometry panel(double width, double height, double z) => Geometry(
        Float32List.fromList([
          -width / 2,
          -height / 2,
          z,
          width / 2,
          -height / 2,
          z,
          width / 2,
          height / 2,
          z,
          -width / 2,
          height / 2,
          z,
        ]),
        [0, 1, 2, 0, 2, 3],
        normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
        uvs: Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
      );

  final city =
      await loadEffectMaterial(viewer, assetsDir: assetsDir, name: 'rain_city');
  await viewer.createGeometry(panel(9.5, 7.2, -2.2), materialInstances: [city]);

  final glass = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'rain_glass');
  await glass.setParameterFloat2('paneSize', 3.5, 2.8);
  await glass.setParameterFloat('time', 2.4);
  await glass.setParameterFloat('rainAmount', .88);
  await glass.setParameterFloat('flowSpeed', 1);
  await glass.setParameterFloat('distortion', .85);
  await glass.setParameterFloat('condensation', .62);
  await viewer.createGeometry(panel(3.5, 2.8, 0), materialInstances: [glass]);

  final frame = await viewer.app.createUbershaderMaterial();
  await frame.setBaseColorFactor(.045, .055, .065, 1);
  await frame.setMetallicFactor(.75);
  await frame.setRoughnessFactor(.3);
  for (final x in [-1.8, 1.8]) {
    await effectBox(viewer, Vector3(x, 0, .04), Vector3(.10, 3.0, .15),
        frame.materialInstance);
  }
  for (final y in [-1.46, 1.46]) {
    await effectBox(viewer, Vector3(0, y, .04), Vector3(3.7, .12, .15),
        frame.materialInstance);
  }
  await effectBox(viewer, Vector3(0, -1.55, .16), Vector3(3.9, .08, .52),
      frame.materialInstance);
  await viewer.addDirectLight(
      DirectLight.sun(direction: Vector3(-.5, -.7, -.5), intensity: 18000));

  for (final spec in <(String, String, double, double, double)>[
    ('Rain amount', 'rainAmount', 0, 1, .85),
    ('Flow speed', 'flowSpeed', 0, 2, 1),
    ('Distortion', 'distortion', 0, 1.5, .65),
    ('Condensation', 'condensation', 0, 1, .28),
  ]) {
    effectSliders.add(EffectSlider(
      spec.$1,
      min: spec.$3,
      max: spec.$4,
      initialValue: spec.$5,
      setValue: (value) async {
        await glass.setParameterFloat(spec.$2, value);
      },
    ));
  }
  effectAnimators.add((t) async {
    await glass.setParameterFloat('time', t);
  });
}
