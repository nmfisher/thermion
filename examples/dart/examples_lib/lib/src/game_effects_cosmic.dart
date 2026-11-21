import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// A closed, inward-visible dome. All sky shading is angular, so the same
/// scene works when the gallery camera rotates, with no screen-space quad.
Future<MaterialInstance> _cosmicSky(
    ThermionViewer viewer, String assetsDir, String name) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
      near: .1,
      far: 1500,
      aspect: viewport.width / viewport.height,
      focalLength: 23);
  await camera.lookAt(Vector3(0, 1.7, 8), focus: Vector3(0, 5.8, -10));
  effectCameraControls =
      EffectCameraControls(focus: Vector3.zero(), lookAround: true);
  await enableVfxPost(viewer, bloomStrength: .09);
  await viewer.setAntiAliasing(false, true, false);
  // The renderer defaults to no dithering. It is essential for smooth dark
  // sky gradients on the eight-bit swapchain used by both gallery and capture.
  await viewer.view.setDithering(true);
  final material =
      await loadEffectMaterial(viewer, assetsDir: assetsDir, name: name);
  final dome = await viewer.createGeometry(
      GeometryUtils.sphere(latitudeBands: 32, longitudeBands: 64),
      materialInstances: [material]);
  await dome.setTransform(Matrix4.diagonal3(Vector3.all(600)));
  await dome.setCastShadows(false);
  await dome.setReceiveShadows(false);
  await material.setParameterFloat('time', 3.2);
  await material.setParameterFloat('speed', 1);
  await material.setParameterFloat('colorShift', 0);
  await material.setParameterFloat('starAmount', 1);
  effectAnimators.add((t) => material.setParameterFloat('time', t));
  return material;
}

/// Closed mountain ring anchors the aurora at the horizon from every angle.
Geometry _mountains() {
  const segments = 192;
  final positions = <double>[], indices = <int>[];
  for (var i = 0; i <= segments; i++) {
    final a = i / segments * math.pi * 2;
    final height = 4.5 +
        4 * math.pow(math.sin(a * 9 + .7).abs(), 3) +
        2.7 * math.sin(a * 17 + 1).abs() +
        math.sin(a * 43).abs();
    for (final y in [-30.0, height]) {
      positions.addAll([math.sin(a) * 90, y, math.cos(a) * 90]);
    }
    if (i < segments) {
      final n = i * 2;
      indices.addAll([n, n + 1, n + 2, n + 2, n + 1, n + 3]);
    }
  }
  return Geometry(Float32List.fromList(positions), indices);
}

Future<void> setupAurora(ThermionViewer viewer,
    {required String assetsDir}) async {
  final sky = await _cosmicSky(viewer, assetsDir, 'aurora');
  await sky.setParameterFloat('intensity', 1.7);
  await sky.setParameterFloat('curtainScale', 1);
  final silhouette = await viewer.app.createUnlitMaterialInstance();
  await silhouette.setParameterFloat4('baseColorFactor', .0005, .001, .0018, 1);
  final mountains = await viewer
      .createGeometry(_mountains(), materialInstances: [silhouette]);
  await mountains.setCastShadows(false);
  // The terrain ring extends below the camera so the lower hemisphere remains
  // solid when looking down from the initial gallery position.
  final floor = await viewer
      .createGeometry(GeometryUtils.cube(), materialInstances: [silhouette]);
  await floor.setTransform(Matrix4.translation(Vector3(0, -31, 0)) *
      Matrix4.diagonal3(Vector3(100, 1, 100)));
  effectSliders.addAll([
    EffectSlider('Aurora brightness',
        min: 0,
        max: 4,
        initialValue: 1.7,
        setValue: (v) => sky.setParameterFloat('intensity', v)),
    EffectSlider('Curtain scale',
        min: .5,
        max: 1.8,
        initialValue: 1,
        setValue: (v) => sky.setParameterFloat('curtainScale', v)),
    ..._skyControls(sky),
  ]);
}

Future<void> setupNebula(ThermionViewer viewer,
    {required String assetsDir}) async {
  final sky = await _cosmicSky(viewer, assetsDir, 'nebula');
  await sky.setParameterFloat('density', 2.2);
  await sky.setParameterFloat('emissionStrength', 1.4);
  await sky.setParameterFloat('dustStrength', 1.1);
  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(0, 0, 8), focus: Vector3(0, 0, 0));
  effectSliders.addAll([
    EffectSlider('Gas density',
        min: 0,
        max: 4,
        initialValue: 2.2,
        setValue: (v) => sky.setParameterFloat('density', v)),
    EffectSlider('Emission',
        min: 0,
        max: 3,
        initialValue: 1.4,
        setValue: (v) => sky.setParameterFloat('emissionStrength', v)),
    EffectSlider('Dark dust',
        min: 0,
        max: 3,
        initialValue: 1.1,
        setValue: (v) => sky.setParameterFloat('dustStrength', v)),
    ..._skyControls(sky),
  ]);
}

List<EffectSlider> _skyControls(MaterialInstance sky) => [
      EffectSlider('Animation speed',
          min: 0,
          max: 3,
          initialValue: 1,
          setValue: (v) => sky.setParameterFloat('speed', v)),
      EffectSlider('Color shift',
          min: 0,
          max: 1,
          initialValue: 0,
          setValue: (v) => sky.setParameterFloat('colorShift', v)),
      EffectSlider('Stars',
          min: 0,
          max: 2,
          initialValue: 1,
          setValue: (v) => sky.setParameterFloat('starAmount', v)),
    ];
