import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Seventy-two curved ribbons, each carrying seventeen procedural strands.
/// UV U encodes the card index plus its width; V runs from root to tip.
Geometry _hairCards() {
  const cards = 72, rows = 28, columns = 4;
  final positions = <double>[], normals = <double>[], uvs = <double>[];
  final indices = <int>[];
  for (var card = 0; card < cards; card++) {
    final ring = card ~/ 24;
    final angle = (card % 24 + ring * .31) * math.pi * 2 / 24;
    // Smooth temple-to-bangs curtain transition instead of an abrupt horizontal shelf.
    final frontFactor = math.pow(math.max(0.0, math.cos(angle - 0.12)), 2.2).toDouble();
    final partSide = math.sin(angle - 0.12) >= 0 ? 1.0 : -1.0;
    Vector3 point(double u, double t) {
      final phi = .10 + ring * .18 + math.min(t / .48, 1) * (1.42 - ring * .15);
      final drop = math.max(0.0, (t - .46) / .54);
      final radius = .68 * math.sin(phi) +
          ring * .025 +
          .035 * math.sin(t * 9 + card * .7) * t;
      // Gently sweep curtain bangs outward from a subtle center-right part.
      final sweep = frontFactor * partSide * drop * 0.24;
      final a = angle + (u - .5) * .38 + sweep + .06 * math.sin(t * 4.5 + ring);
      final dropLen = (1.12 + .12 * math.sin(card * 3)) * (1.0 - 0.58 * frontFactor);
      final y = .86 * math.cos(phi) - drop * dropLen;
      return Vector3(radius * math.sin(a), y, radius * math.cos(a));
    }

    final base = positions.length ~/ 3;
    for (var row = 0; row <= rows; row++) {
      for (var col = 0; col <= columns; col++) {
        final u = col / columns, v = row / rows;
        final p = point(u, v);
        final du = point(u + .001, v) - p;
        final dv = point(u, v + .001) - p;
        final n = dv.cross(du)..normalize();
        positions.addAll([p.x, p.y, p.z]);
        normals.addAll([n.x, n.y, n.z]);
        // Keep the right edge within this card's integer interval.
        uvs.addAll([card + u * .9999, v]);
        if (row < rows && col < columns) {
          final a = base + row * (columns + 1) + col;
          final b = a + columns + 1;
          indices.addAll([a, b, a + 1, a + 1, b, b + 1]);
        }
      }
    }
  }
  return Geometry(Float32List.fromList(positions), indices,
      normals: Float32List.fromList(normals), uvs: Float32List.fromList(uvs));
}

Future<void> setupHairFur(ThermionViewer viewer,
    {required String assetsDir}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
      near: .1,
      far: 100,
      aspect: viewport.width / viewport.height,
      focalLength: 42);
  await camera.lookAt(Vector3(3.2, 2.7, 9.7), focus: Vector3(0, 1.35, 0));
  effectCameraControls = EffectCameraControls(focus: Vector3(0, 1.35, 0));
  await setDarkSkybox(viewer);
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 12000);
  await enableVfxPost(viewer, bloomStrength: .025);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);
  await viewer.addDirectLight(DirectLight.sun(
      direction: Vector3(.5, -.5, -.65),
      color: const LinearColor(1, .88, .72),
      intensity: 42000,
      castShadows: true));
  await viewer.addDirectLight(DirectLight.point(
      position: Vector3(2.5, 3, -2),
      color: const LinearColor(.55, .72, 1),
      intensity: 65000,
      falloffRadius: 12));

  final stand = await viewer.app.createUbershaderMaterial();
  await stand.setBaseColorFactor(.045, .05, .065, 1);
  await stand.setMetallicFactor(.6);
  await stand.setRoughnessFactor(.28);
  final floor = await effectBox(viewer, Vector3(0, -.06, 0),
      Vector3(5.8, .12, 3), stand.materialInstance);
  await floor.setReceiveShadows(true);
  for (final x in [-1.35, 1.35]) {
    await effectBox(viewer, Vector3(x, .16, 0), Vector3(1.7, .32, 1.55),
        stand.materialInstance);
  }
  final mannequin = await viewer.app.createUbershaderMaterial();
  await mannequin.setBaseColorFactor(.13, .15, .17, 1);
  await mannequin.setRoughnessFactor(.4);
  final head = await viewer.createGeometry(
      GeometryUtils.sphere(latitudeBands: 48, longitudeBands: 64),
      materialInstances: [mannequin.materialInstance]);
  await head.setTransform(Matrix4.translation(Vector3(-1.35, 1.83, 0)) *
      Matrix4.diagonal3(Vector3(.62, .8, .62)));
  await head.setCastShadows(true);
  await head.setReceiveShadows(true);
  await effectBox(viewer, Vector3(-1.35, .65, 0), Vector3(.45, .7, .45),
      stand.materialInstance);
  final hair = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'hair_cards');
  await hair.setParameterFloat3('rootColor', .024, .008, .004);
  await hair.setParameterFloat3('tipColor', .26, .085, .022);
  await hair.setParameterFloat('roughness', .3);
  await hair.setParameterFloat('anisotropy', .85);
  final locks =
      await viewer.createGeometry(_hairCards(), materialInstances: [hair]);
  await locks.setTransform(Matrix4.translation(Vector3(-1.35, 1.83, 0)));
  await locks.setCastShadows(true);
  await locks.setReceiveShadows(true);

  final furBytes =
      await viewer.app.loadResource('$assetsDir/fur_shell.filamat');
  final furMaterial = await viewer.app.createMaterial(furBytes);
  final shells = <MaterialInstance>[];
  final sphere = GeometryUtils.sphere(latitudeBands: 48, longitudeBands: 72);
  const shellCount = 28;
  for (var i = 0; i < shellCount; i++) {
    final shell = await furMaterial.createInstance();
    await shell.setParameterFloat('layer', i / (shellCount - 1));
    await shell.setParameterFloat('furLength', .16);
    await shell.setParameterFloat('grooming', .45);
    await shell.setParameterFloat('strandScale', 92);
    final mesh =
        await viewer.createGeometry(sphere, materialInstances: [shell]);
    await mesh.setTransform(Matrix4.translation(Vector3(1.35, 1.48, 0)) *
        Matrix4.diagonal3(Vector3(.84, .98, .84)));
    // Base casts the main shadow; outer layers receive scene lighting without
    // multiplying shadow-map draw calls or self-shadow aliasing twenty-eightfold.
    await mesh.setCastShadows(i == 0);
    await mesh.setReceiveShadows(true);
    shells.add(shell);
  }
  final fibers = [hair, ...shells];
  Future<void> shared(String name, double value) async {
    for (final material in fibers) {
      await material.setParameterFloat(name, value);
    }
  }

  Future<void> furOnly(String name, double value) async {
    for (final material in shells) {
      await material.setParameterFloat(name, value);
    }
  }

  await shared('time', 1.8);
  await shared('windSpeed', 1);
  await shared('windStrength', .6);
  effectSliders.addAll([
    EffectSlider('Wind strength',
        min: 0,
        max: 1.5,
        initialValue: .6,
        setValue: (v) => shared('windStrength', v)),
    EffectSlider('Wind speed',
        min: 0,
        max: 2.5,
        initialValue: 1,
        setValue: (v) => shared('windSpeed', v)),
    EffectSlider('Hair roughness',
        min: .15,
        max: .7,
        initialValue: .3,
        setValue: (v) => hair.setParameterFloat('roughness', v)),
    EffectSlider('Hair anisotropy',
        min: 0,
        max: .95,
        initialValue: .85,
        setValue: (v) => hair.setParameterFloat('anisotropy', v)),
    EffectSlider('Fur length',
        min: 0,
        max: .4,
        initialValue: .16,
        setValue: (v) => furOnly('furLength', v)),
    EffectSlider('Fur grooming',
        min: 0,
        max: 1,
        initialValue: .45,
        setValue: (v) => furOnly('grooming', v)),
    EffectSlider('Fur density',
        min: 24,
        max: 100,
        step: 1,
        initialValue: 92,
        setValue: (v) => furOnly('strandScale', v.roundToDouble())),
  ]);
  effectAnimators.add((t) => shared('time', t));
}
