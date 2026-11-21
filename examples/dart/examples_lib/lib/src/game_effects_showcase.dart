import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_cloth.dart';
import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';
import 'showcase_performance.dart';

enum ShowcaseEffect {
  aurora('Aurora'),
  storm('Tornado'),
  cloth('Banners'),
  glass('Rain glass'),
  iridescence('Iridescent relic'),
  fur('Fur');

  const ShowcaseEffect(this.label);
  final String label;
}

enum ShowcaseShot {
  overview('Observatory'),
  window('Rain window'),
  relic('Relic'),
  fibers('Fibers'),
  storm('Storm');

  const ShowcaseShot(this.label);
  final String label;
  Vector3 get eye => switch (this) {
        overview => Vector3(11, 6.6, 18),
        window => Vector3(-2, 2.4, 6.8),
        relic => Vector3(3, 2.9, 6),
        fibers => Vector3(-4.7, 2.8, 7.1),
        storm => Vector3(12, 4.5, 8),
      };
  Vector3 get focus => switch (this) {
        overview => Vector3(0, 2, -1),
        window => Vector3(-3.8, 2.2, .5),
        relic => Vector3(0, 1.8, 0),
        fibers => Vector3(-2.7, 1.5, .7),
        storm => Vector3(6, 2.5, -7),
      };
}

/// Shared scene controller. Runners own the clock, surface and render loop.
/// Mutations are serialized against animation, so UI toggles/presets cannot
/// interleave a partially updated frame or race scene teardown.
class EffectsShowcase {
  EffectsShowcase._(this.viewer);
  final ThermionViewer viewer;
  final Map<ShowcaseEffect, bool> enabled = {
    for (final e in ShowcaseEffect.values) e: true
  };
  final Map<ShowcaseEffect, List<ThermionAsset>> _groups = {
    for (final e in ShowcaseEffect.values) e: []
  };
  final Map<ShowcaseEffect, List<MaterialInstance>> _animated = {
    for (final e in ShowcaseEffect.values) e: []
  };
  final Map<String, Material> _materials = {};
  final List<MaterialInstance> _fur = [];
  final Set<ThermionAsset> _hidden = {};
  late MaterialInstance _aurora, _storm, _glass;
  ShowcaseQuality quality = ShowcaseQuality.balanced;
  // Groups Dart futures for comparison with sequential awaits; this does not
  // combine native calls or reduce the number of uniform writes.
  bool batchUpdates = true;
  bool _disposed = false;
  double? _lastTime;
  Future<void> _pending = Future.value();
  int get visibleFurShells =>
      enabled[ShowcaseEffect.fur]! ? quality.furShells : 0;
  int get animatedMaterialCount => _animated.entries.fold(
      0,
      (n, e) =>
          n +
          (!enabled[e.key]!
              ? 0
              : e.key == ShowcaseEffect.fur
                  ? quality.furShells
                  : e.value.length));

  static Future<EffectsShowcase> create(ThermionViewer viewer,
      {required String assetsDir,
      ShowcaseQuality quality = ShowcaseQuality.balanced}) async {
    final showcase = EffectsShowcase._(viewer);
    await showcase._build(assetsDir);
    await showcase.setQuality(quality);
    await showcase.update(3.2);
    return showcase;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _pending.then((_) async {
      if (!_disposed) await action();
    });
    // Keep the queue usable after an error, but propagate that error to caller.
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _pending;
  }

  Future<void> update(double seconds) => _serialize(() async {
        if (_lastTime == seconds) return;
        final materials = <MaterialInstance>[];
        for (final e in _animated.entries) {
          if (!enabled[e.key]!) continue;
          materials.addAll(e.key == ShowcaseEffect.fur
              ? e.value.take(quality.furShells)
              : e.value);
        }
        if (batchUpdates) {
          await Future.wait(
              materials.map((m) => m.setParameterFloat('time', seconds)));
        } else {
          for (final material in materials) {
            await material.setParameterFloat('time', seconds);
          }
        }
        _lastTime = seconds;
      });

  Future<void> _visible(ThermionAsset asset, bool visible) async {
    final scene = await viewer.view.getScene();
    if (visible && _hidden.remove(asset)) await scene.add(asset);
    if (!visible && _hidden.add(asset)) await scene.remove(asset);
  }

  Future<void> setEnabled(ShowcaseEffect effect, bool value) =>
      _serialize(() async {
        enabled[effect] = value;
        final meshes = _groups[effect]!;
        for (var i = 0; i < meshes.length; i++) {
          await _visible(meshes[i],
              value && (effect != ShowcaseEffect.fur || i < quality.furShells));
        }
        _lastTime = null;
      });

  Future<void> setQuality(ShowcaseQuality value) => _serialize(() async {
        quality = value;
        await _aurora.setParameterFloat(
            'sampleCount', value.auroraSamples.toDouble());
        await _storm.setParameterFloat(
            'sampleCount', value.stormSamples.toDouble());
        await viewer.setShadowsEnabled(value.shadows);
        for (var i = 0; i < _fur.length; i++) {
          if (i < value.furShells)
            await _fur[i].setParameterFloat('layer', i / (value.furShells - 1));
          await _visible(_groups[ShowcaseEffect.fur]![i],
              enabled[ShowcaseEffect.fur]! && i < value.furShells);
        }
        _lastTime = null;
      });

  Future<void> setWind(double strength) => _serialize(() async {
        for (final m in [..._animated[ShowcaseEffect.cloth]!, ..._fur]) {
          await m.setParameterFloat('windStrength', strength);
        }
        await _storm.setParameterFloat('turbulence', .4 + strength);
      });
  Future<void> setRain(double amount) => _serialize(() async {
        await _glass.setParameterFloat('rainAmount', amount);
      });
  Future<void> setShot(ShowcaseShot shot) => _serialize(() async {
        await (await viewer.getActiveCamera())
            .lookAt(shot.eye, focus: shot.focus);
      });

  /// Identical closed path at every quality level and in every runner.
  Future<void> setTour(double seconds) => _serialize(() async {
        final angle = .34 + .32 * math.sin(seconds * math.pi * 2 / 20);
        final eye = Vector3(math.sin(angle) * 20,
            5.9 + .8 * math.sin(seconds * .314), math.cos(angle) * 20);
        await (await viewer.getActiveCamera())
            .lookAt(eye, focus: ShowcaseShot.overview.focus);
      });

  Future<MaterialInstance> _material(
      String name, String assetsDir, ShowcaseEffect group) async {
    var material = _materials[name];
    if (material == null) {
      material = await viewer.app.createMaterial(
          await viewer.app.loadResource('$assetsDir/$name.filamat'));
      _materials[name] = material;
    }
    final instance = await material.createInstance();
    _animated[group]!.add(instance);
    return instance;
  }

  Future<ThermionAsset> _mesh(
      Geometry geometry, MaterialInstance material, Matrix4 transform,
      {ShowcaseEffect? group, bool shadows = true}) async {
    final asset =
        await viewer.createGeometry(geometry, materialInstances: [material]);
    await asset.setTransform(transform);
    await asset.setCastShadows(shadows);
    await asset.setReceiveShadows(shadows);
    if (group != null) _groups[group]!.add(asset);
    return asset;
  }

  Future<void> _build(String assetsDir) async {
    final camera = await viewer.getActiveCamera();
    final viewport = await viewer.view.getViewport();
    await camera.setLensProjection(
        near: .1,
        far: 1000,
        aspect: viewport.height > 0 ? viewport.width / viewport.height : 1,
        focalLength: 30);
    await camera.lookAt(ShowcaseShot.overview.eye,
        focus: ShowcaseShot.overview.focus);
    await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 7000);
    await setDarkSkybox(viewer);
    await enableVfxPost(viewer, bloomStrength: .045);
    await viewer.setAntiAliasing(false, true, false);
    await viewer.view.setDithering(true);
    await viewer.addDirectLight(DirectLight.sun(
        direction: Vector3(.45, -.65, -.7),
        color: const LinearColor(.66, .8, 1),
        intensity: 28000,
        castShadows: true));
    await viewer.addDirectLight(DirectLight.point(
        position: Vector3(0, 3, 2),
        color: const LinearColor(1, .57, .23),
        intensity: 42000,
        falloffRadius: 14));
    final stone = await viewer.app.createUbershaderMaterial();
    await stone.setBaseColorFactor(.085, .10, .12, 1);
    await stone.setRoughnessFactor(.68);
    final dark = await viewer.app.createUbershaderMaterial();
    await dark.setBaseColorFactor(.025, .035, .047, 1);
    await dark.setMetallicFactor(.35);
    await dark.setRoughnessFactor(.23);
    final earth = await viewer.app.createUbershaderMaterial();
    await earth.setBaseColorFactor(.018, .026, .03, 1);
    await earth.setRoughnessFactor(.93);
    await _mesh(GeometryUtils.plane(width: 70, height: 70), earth.materialInstance,
        Matrix4.translation(Vector3(0, -.52, -7)));
    Future<void> box(Vector3 p, Vector3 s, MaterialInstance m) async {
      final asset = await effectBox(viewer, p, s, m);
      await asset.setCastShadows(true);
      await asset.setReceiveShadows(true);
    }

    await box(
        Vector3(0, -.25, -.5), Vector3(12.6, .5, 11.5), stone.materialInstance);
    await box(
        Vector3(0, -.48, 5.6), Vector3(8, .45, 1.4), dark.materialInstance);
    for (final x in [-4.6, 4.6]) {
      for (final z in [-3.8, 2.8]) {
        final height = x > 0 && z > 0 ? 2.6 : 4.5;
        await box(Vector3(x, height / 2, z), Vector3(.52, height, .52),
            stone.materialInstance);
        await box(
            Vector3(x, .18, z), Vector3(.92, .36, .92), dark.materialInstance);
        await box(Vector3(x, height - .12, z), Vector3(.82, .24, .82),
            dark.materialInstance);
      }
    }
    await box(
        Vector3(0, 4.36, -3.8), Vector3(9.7, .36, .7), stone.materialInstance);
    // Broad joints and inset slabs give the courtyard scale and grazing highlights.
    for (var x = -2; x <= 2; x++) {
      for (var z = -2; z <= 2; z++) {
        await box(Vector3(x * 2.25, .025, z * 1.9), Vector3(2.18, .05, 1.83),
            dark.materialInstance);
      }
    }
    await box(
        Vector3(0, .42, -.4), Vector3(2.25, .84, 2.1), stone.materialInstance);
    await box(
        Vector3(0, .89, -.4), Vector3(2.5, .12, 2.3), dark.materialInstance);
    await box(Vector3(-2.5, .48, 2.2), Vector3(2.3, .96, 1.3),
        stone.materialInstance);
    await _buildEffects(assetsDir, dark.materialInstance);
  }

  Future<void> _buildEffects(String assetsDir, MaterialInstance frame) async {
    _aurora = await _material('aurora', assetsDir, ShowcaseEffect.aurora);
    for (final p in {
      'speed': .7,
      'intensity': 1.3,
      'curtainScale': 1.0,
      'colorShift': .15,
      'starAmount': .65
    }.entries) {
      await _aurora.setParameterFloat(p.key, p.value);
    }
    await _mesh(GeometryUtils.sphere(latitudeBands: 24, longitudeBands: 48),
        _aurora, Matrix4.diagonal3(Vector3.all(400)),
        group: ShowcaseEffect.aurora, shadows: false);
    _storm = await _material('storm_volume', assetsDir, ShowcaseEffect.storm);
    for (final p in {
      'windSpeed': 1.0,
      'density': 2.2,
      'turbulence': 1.0,
      'funnelWidth': 1.0,
      'stormType': 0.0
    }.entries) {
      await _storm.setParameterFloat(p.key, p.value);
    }
    await _storm.setParameterFloat3('volumeOrigin', 6, 0, -7);
    await _storm.setParameterFloat3('volumeMin', 2.9, 0, -10.1);
    await _storm.setParameterFloat3('volumeMax', 9.1, 5.4, -3.9);
    await _storm.setParameterFloat3('dustColor', .25, .29, .36);
    await _mesh(
        GeometryUtils.cube(),
        _storm,
        Matrix4.translation(Vector3(6, 2.7, -7)) *
            Matrix4.diagonal3(Vector3(3.1, 2.7, 3.1)),
        group: ShowcaseEffect.storm,
        shadows: false);
    for (final spec in [
      ('silk', -3.1, Vector3(.018, .13, .15)),
      ('woven_cloth', 3.1, Vector3(.23, .075, .022))
    ]) {
      final cloth = await _material(spec.$1, assetsDir, ShowcaseEffect.cloth);
      await cloth.setParameterFloat3(
          'fabricColor', spec.$3.x, spec.$3.y, spec.$3.z);
      await cloth.setParameterFloat2('clothSize', 1.45, 2.7);
      for (final p in {
        'windSpeed': 1.0,
        'windStrength': .75,
        'weaveScale': 60.0,
        'weaveStrength': .6
      }.entries) {
        await cloth.setParameterFloat(p.key, p.value);
      }
      if (spec.$1 == 'silk') {
        await cloth.setParameterFloat('roughness', .3);
        await cloth.setParameterFloat('anisotropy', .8);
      }
      await _mesh(effectFabricPanel(1.45, 2.7, nx: 32, ny: 48), cloth,
          Matrix4.translation(Vector3(spec.$2, 1.25, -3.4)),
          group: ShowcaseEffect.cloth);
      await effectBox(
          viewer, Vector3(spec.$2, 3.97, -3.4), Vector3(1.65, .06, .1), frame);
    }
    _glass = await _material('rain_glass', assetsDir, ShowcaseEffect.glass);
    await _glass.setParameterFloat2('paneSize', 2.25, 2.65);
    for (final p in {
      'rainAmount': .85,
      'flowSpeed': 1.0,
      'distortion': .75,
      'condensation': .15
    }.entries) {
      await _glass.setParameterFloat(p.key, p.value);
    }
    await _mesh(effectFabricPanel(2.25, 2.65, nx: 1, ny: 1), _glass,
        Matrix4.translation(Vector3(-3.7, .7, .4)),
        group: ShowcaseEffect.glass, shadows: false);
    for (final x in [-4.85, -2.55]) {
      await effectBox(viewer, Vector3(x, 2, .4), Vector3(.10, 2.9, .15), frame);
    }
    for (final y in [.65, 3.4]) {
      await effectBox(
          viewer, Vector3(-3.7, y, .4), Vector3(2.4, .12, .15), frame);
    }
    final relic = await _material(
        'iridescent_surface', assetsDir, ShowcaseEffect.iridescence);
    for (final p in {
      'speed': 1.0,
      'thickness': 480.0,
      'variation': 160.0,
      'filmIor': 1.85,
      'strength': 1.0,
      'roughness': .16,
      'preset': 0.0
    }.entries) {
      await relic.setParameterFloat(p.key, p.value);
    }
    await _mesh(
        GeometryUtils.sphere(latitudeBands: 48, longitudeBands: 64),
        relic,
        Matrix4.translation(Vector3(0, 2, -.4)) *
            Matrix4.diagonal3(Vector3(.78, 1.02, .78)),
        group: ShowcaseEffect.iridescence);
    final sphere = GeometryUtils.sphere(latitudeBands: 32, longitudeBands: 48);
    for (var i = 0; i < ShowcaseQuality.high.furShells; i++) {
      final fur = await _material('fur_shell', assetsDir, ShowcaseEffect.fur);
      for (final p in {
        'windSpeed': 1.0,
        'windStrength': .75,
        'furLength': .15,
        'grooming': .6,
        'strandScale': 64.0
      }.entries) {
        await fur.setParameterFloat(p.key, p.value);
      }
      await fur.setParameterFloat('layer', i / 27);
      final mesh = await _mesh(
          sphere,
          fur,
          Matrix4.translation(Vector3(-2.5, 1.15, 2.2)) *
              Matrix4.diagonal3(Vector3(.95, .28, .48)),
          group: ShowcaseEffect.fur,
          shadows: false);
      await mesh.setReceiveShadows(true);
      await mesh.setCastShadows(i == 0);
      _fur.add(fur);
    }
  }
}

Future<void> setupShowcase(ThermionViewer viewer,
    {required String assetsDir}) async {
  final scene = await EffectsShowcase.create(viewer, assetsDir: assetsDir);
  effectCameraControls =
      EffectCameraControls(focus: ShowcaseShot.overview.focus);
  effectAnimators.add(scene.update);
  effectSliders.add(EffectSlider('Quality',
      min: 0,
      max: 2,
      step: 1,
      initialValue: 1,
      setValue: (v) =>
          scene.setQuality(ShowcaseQuality.values[v.round().clamp(0, 2)])));
  for (final effect in ShowcaseEffect.values) {
    effectSliders.add(EffectSlider(effect.label,
        min: 0,
        max: 1,
        step: 1,
        initialValue: 1,
        setValue: (v) => scene.setEnabled(effect, v >= .5)));
  }
  viewer.onDispose(scene.dispose);
}
