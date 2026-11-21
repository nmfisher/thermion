import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Submerged stone temple ruins bathed in chromatic R/G/B-dispersed Voronoi
/// wave caustics, Beer-Lambert underwater depth murk, and aligned volumetric
/// marine sun-shafts with drifting marine snow.
Future<void> setupUnderwaterCaustics(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: viewport.height > 0 ? viewport.width / viewport.height : 1.0,
    focalLength: 32,
  );
  final focus = Vector3(0, 0.95, -0.3);
  await camera.lookAt(Vector3(2.6, 1.85, 6.2), focus: focus);
  effectCameraControls = EffectCameraControls(focus: focus);

  // Deep abyssal teal-cobalt ocean background matching Beer-Lambert fog!
  final scene = await viewer.view.getScene();
  await scene.setSkybox(
    await viewer.app.createColoredSkybox(r: 0.005, g: 0.045, b: 0.082, a: 1.0),
  );
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 6500);
  await enableVfxPost(viewer, bloomStrength: 0.12);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);

  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-0.32, -0.88, -0.35),
      color: const LinearColor(0.42, 0.88, 0.96),
      intensity: 48000,
      castShadows: true,
    ),
  );

  final sandMat = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'underwater_caustics',
  );
  await sandMat.setParameterFloat('time', 0.0);
  await sandMat.setParameterFloat('causticIntensity', 1.25);
  await sandMat.setParameterFloat('dispersion', 1.0);
  await sandMat.setParameterFloat('murkiness', 0.95);
  await sandMat.setParameterFloat('isSand', 1.0);

  final stoneMat = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'underwater_caustics',
  );
  await stoneMat.setParameterFloat('time', 0.0);
  await stoneMat.setParameterFloat('causticIntensity', 1.25);
  await stoneMat.setParameterFloat('dispersion', 1.0);
  await stoneMat.setParameterFloat('murkiness', 0.95);
  await stoneMat.setParameterFloat('isSand', 0.0);

  // Rippled ocean seabed mesh.
  final seabed = await viewer.createGeometry(
    subdividedPlane(width: 26, depth: 26, subdivisionsX: 96, subdivisionsZ: 96),
    materialInstances: [sandMat],
  );
  await seabed.setReceiveShadows(true);

  // Sunken ancient temple ruins: stepped altar dais, colonnade pillars, broken architrave, and sunken bust!
  Future<void> ruinBox(Vector3 pos, Vector3 size, {double rotZ = 0.0, double rotY = 0.0}) async {
    final b = await viewer.createGeometry(
      GeometryUtils.cube(),
      materialInstances: [stoneMat],
    );
    await b.setTransform(
      Matrix4.translation(pos) *
          Matrix4.rotationY(rotY) *
          Matrix4.rotationZ(rotZ) *
          Matrix4.diagonal3(size * 0.5),
    );
    await b.setCastShadows(true);
    await b.setReceiveShadows(true);
  }

  await ruinBox(Vector3(0, 0.14, -0.4), Vector3(5.2, 0.32, 4.2));
  await ruinBox(Vector3(0, 0.38, -0.4), Vector3(3.8, 0.24, 2.9));

  // Standing + broken fallen columns
  for (final (x, z, h) in [
    (-1.95, -1.45, 2.65),
    (1.95, -1.45, 2.65),
    (-1.95, 0.75, 1.75),
    (1.95, 0.75, 2.15),
  ]) {
    await ruinBox(Vector3(x, 0.30, z), Vector3(0.68, 0.22, 0.68));
    await ruinBox(Vector3(x, 0.30 + h * 0.5, z), Vector3(0.46, h, 0.46));
  }
  // Intact rear temple lintel beam + fallen stone block on the sand!
  await ruinBox(Vector3(0, 3.08, -1.45), Vector3(4.65, 0.38, 0.62));
  await ruinBox(Vector3(-0.85, 0.22, 1.85), Vector3(1.35, 0.42, 0.48),
      rotZ: 0.18, rotY: 0.42);

  // Sunken bronze/stone relic FlightHelmet resting on the temple altar!
  final relic =
      await viewer.loadGltf('$assetsDir/FlightHelmet/FlightHelmet.gltf');
  await relic.setMaterialInstanceForAll(stoneMat);
  await relic.setTransform(
    Matrix4.translation(Vector3(0.1, 0.50, -0.35)) *
        Matrix4.rotationY(-0.35) *
        Matrix4.rotationZ(0.14) *
        Matrix4.diagonal3(Vector3.all(1.85)),
  );

  // Crossed volumetric sun-shaft curtains descending through the water!
  final shaftMat = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'underwater_shafts',
  );
  await shaftMat.setParameterFloat('time', 0.0);
  await shaftMat.setParameterFloat('shaftStrength', 1.0);

  for (var i = 0; i < 5; i++) {
    final z = -1.8 + i * 0.95;
    final yaw = (i.isEven ? 0.18 : -0.22);
    final curtain = await viewer.createGeometry(
      GeometryUtils.plane(width: 7.5, height: 4.8),
      materialInstances: [shaftMat],
    );
    await curtain.setTransform(
      Matrix4.translation(Vector3(0, 2.1, z)) *
          Matrix4.rotationY(yaw) *
          Matrix4.rotationX(math.pi * 0.5),
    );
    await curtain.setCastShadows(false);
  }

  Future<void> sharedSurface(String name, double v) async {
    await sandMat.setParameterFloat(name, v);
    await stoneMat.setParameterFloat(name, v);
  }

  effectSliders.addAll([
    EffectSlider(
      'Caustic brightness',
      min: 0.0,
      max: 2.5,
      initialValue: 1.25,
      setValue: (v) => sharedSurface('causticIntensity', v),
    ),
    EffectSlider(
      'Chromatic prism',
      min: 0.0,
      max: 2.5,
      initialValue: 1.0,
      setValue: (v) => sharedSurface('dispersion', v),
    ),
    EffectSlider(
      'Depth murk',
      min: 0.1,
      max: 2.2,
      initialValue: 0.95,
      setValue: (v) => sharedSurface('murkiness', v),
    ),
    EffectSlider(
      'Sun-shaft strength',
      min: 0.0,
      max: 2.2,
      initialValue: 1.0,
      setValue: (v) => shaftMat.setParameterFloat('shaftStrength', v),
    ),
  ]);

  effectAnimators.add((t) async {
    await sandMat.setParameterFloat('time', t);
    await stoneMat.setParameterFloat('time', t);
    await shaftMat.setParameterFloat('time', t);
    if (!effectCameraUserControlled) {
      final drift = 0.38 + 0.24 * math.sin(t * math.pi * 2 / 6.0);
      await camera.lookAt(
        Vector3(math.sin(drift) * 6.6, 1.82 + 0.15 * math.cos(t * 1.05),
            math.cos(drift) * 6.6),
        focus: focus,
      );
    }
  });
}
