import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Sculpted aerodynamic automotive speedform shell with a crisp central hood
/// crease, flared fenders, and compound curves designed to showcase flip-flop
/// chameleon pigments and clear-coat studio light strips.
Geometry _automotiveSpeedform({int segX = 96, int segZ = 128}) {
  final vertCount = (segX + 1) * (segZ + 1);
  final vertices = Float32List(vertCount * 3);
  final normals = Float32List(vertCount * 3);
  final uvs = Float32List(vertCount * 2);
  final indices = <int>[];

  Vector3 eval(double u, double v) {
    final s = (u - 0.5) * 2.0; // -1..1 across width
    final z = (v - 0.5) * 2.25; // -1.125..1.125 along length
    final noseTaper = math.sqrt(math.max(1.0 - (v * 2.0 - 1.0) * (v * 2.0 - 1.0) * 0.88, 0.04));
    final waist = 1.0 - 0.16 * math.exp(-math.pow((v - 0.48) * 3.8, 2));
    final halfW = 0.58 * noseTaper * waist;
    final x = s * halfW;

    // Arching Le-Mans cockpit/fender profile + central sculpted spine crease!
    final longArch = math.sin(v * math.pi) * (0.42 + 0.16 * math.sin(v * math.pi * 2.0 - 0.6));
    final crossDoming = math.sqrt(math.max(1.0 - s * s * 0.92, 0.02));
    final fenderFlare = 0.09 * math.exp(-math.pow((s.abs() - 0.68) * 4.5, 2)) * math.sin(v * math.pi);
    final spineCrease = 0.038 * math.exp(-s.abs() * 7.5) * math.sin(v * math.pi);
    final y = longArch * crossDoming + fenderFlare + spineCrease;
    return Vector3(x, y, z);
  }

  const eps = 0.004;
  for (var j = 0; j <= segZ; j++) {
    final v = j / segZ;
    for (var i = 0; i <= segX; i++) {
      final u = i / segX;
      final p = eval(u, v);
      final pu = eval((u + eps).clamp(0.0, 1.0), v) - eval((u - eps).clamp(0.0, 1.0), v);
      final pv = eval(u, (v + eps).clamp(0.0, 1.0)) - eval(u, (v - eps).clamp(0.0, 1.0));
      final n = pv.cross(pu);
      if (n.length2 > 1e-9) {
        n.normalize();
      } else {
        n.setValues(0, 1, 0);
      }
      final idx = j * (segX + 1) + i;
      vertices[idx * 3] = p.x;
      vertices[idx * 3 + 1] = p.y;
      vertices[idx * 3 + 2] = p.z;
      normals[idx * 3] = n.x;
      normals[idx * 3 + 1] = n.y;
      normals[idx * 3 + 2] = n.z;
      uvs[idx * 2] = u;
      uvs[idx * 2 + 1] = v;
    }
  }

  for (var j = 0; j < segZ; j++) {
    for (var i = 0; i < segX; i++) {
      final tl = j * (segX + 1) + i;
      final tr = tl + 1;
      final bl = tl + (segX + 1);
      final br = bl + 1;
      indices.addAll([tl, bl, tr, tr, bl, br]);
    }
  }
  return Geometry(vertices, indices, normals: normals, uvs: uvs);
}

/// Multi-flake chameleon automotive car paint (`clearCoat: 1.0` + stochastic 3D
/// Voronoi metallic micro-flakes) showcased on three turntable speedforms under
/// overhead studio softbox strips.
Future<void> setupCarPaint(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: viewport.height > 0 ? viewport.width / viewport.height : 1.0,
    focalLength: 38,
  );
  final focus = Vector3(0, 0.45, 0);
  await camera.lookAt(Vector3(2.8, 2.25, 5.4), focus: focus);
  effectCameraControls = EffectCameraControls(focus: focus);

  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 24000);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.10);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);

  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-0.42, -0.82, -0.38),
      color: const LinearColor(0.96, 0.98, 1.0),
      intensity: 62000,
      castShadows: true,
    ),
  );
  await viewer.addDirectLight(
    DirectLight.point(
      position: Vector3(2.4, 2.8, -1.8),
      color: const LinearColor(0.82, 0.90, 1.0),
      intensity: 110000,
      falloffRadius: 12.0,
    ),
  );

  // Dark showroom turntable floor + overhead illuminated studio softbox ribs.
  final floorMat = await viewer.app.createUbershaderMaterial();
  await floorMat.setBaseColorFactor(0.018, 0.022, 0.030, 1.0);
  await floorMat.setMetallicFactor(0.45);
  await floorMat.setRoughnessFactor(0.20);
  final floor = await effectBox(
      viewer, Vector3(0, -0.08, 0), Vector3(9.5, 0.16, 6.5), floorMat.materialInstance);
  await floor.setReceiveShadows(true);

  final softboxMat = await viewer.app.createUbershaderMaterial();
  await softboxMat.setBaseColorFactor(0.95, 0.97, 1.0, 1.0);
  await softboxMat.materialInstance
      .setParameterFloat4('emissiveFactor', 1.0, 1.0, 1.0, 0.92);
  for (final x in [-1.6, 0.0, 1.6]) {
    final strip = await effectBox(
      viewer,
      Vector3(x, 3.25, -0.4),
      Vector3(0.28, 0.04, 4.2),
      softboxMat.materialInstance,
    );
    await strip.setCastShadows(false);
  }

  final speedformGeom = _automotiveSpeedform();
  final paints = <MaterialInstance>[];
  final cars = <ThermionAsset>[];
  final specs = <(double, double, double)>[
    (0.0, -1.55, 0.22), // Midnight Sapphire-Violet Chameleon
    (1.0, 0.0, 0.0), // Molten Sunset Crimson-Gold
    (2.0, 1.55, -0.22), // Racing Emerald-Lime Flip
  ];

  for (final (preset, x, baseYaw) in specs) {
    final mat = await loadEffectMaterial(
      viewer,
      assetsDir: assetsDir,
      name: 'car_paint',
    );
    await mat.setParameterFloat('time', 0.0);
    await mat.setParameterFloat('preset', preset);
    await mat.setParameterFloat('flakeScale', 340.0);
    await mat.setParameterFloat('flakeStrength', 1.0);
    await mat.setParameterFloat('clearCoat', 1.0);
    paints.add(mat);

    final plinth = await effectBox(
      viewer,
      Vector3(x, 0.08, 0),
      Vector3(1.38, 0.16, 2.48),
      floorMat.materialInstance,
    );
    await plinth.setReceiveShadows(true);

    final car = await viewer.createGeometry(
      speedformGeom,
      materialInstances: [mat],
    );
    await car.setTransform(
      Matrix4.translation(Vector3(x, 0.17, 0)) * Matrix4.rotationY(baseYaw),
    );
    await car.setCastShadows(true);
    await car.setReceiveShadows(true);
    cars.add(car);
  }

  Future<void> shared(String name, double v) async {
    for (final m in paints) {
      await m.setParameterFloat(name, v);
    }
  }

  effectSliders.addAll([
    EffectSlider(
      'Flake density',
      min: 120,
      max: 520,
      step: 1,
      initialValue: 340,
      setValue: (v) => shared('flakeScale', v),
    ),
    EffectSlider(
      'Flake sparkle',
      min: 0.0,
      max: 1.5,
      initialValue: 1.0,
      setValue: (v) => shared('flakeStrength', v),
    ),
    EffectSlider(
      'Clear coat gloss',
      min: 0.0,
      max: 1.0,
      initialValue: 1.0,
      setValue: (v) => shared('clearCoat', v),
    ),
  ]);

  Future<void> animate(double t) async {
    await shared('time', t);
    for (var i = 0; i < cars.length; i++) {
      final yaw = specs[i].$3 + 0.55 * math.sin(t * math.pi * 2 / 6.0 + i * 0.7);
      await cars[i].setTransform(
        Matrix4.translation(Vector3(specs[i].$2, 0.17, 0)) *
            Matrix4.rotationY(yaw),
      );
    }
    if (!effectCameraUserControlled) {
      final camAngle = 0.34 * math.sin(t * math.pi * 2 / 6.0);
      await camera.lookAt(
        Vector3(math.sin(camAngle) * 5.85, 2.05, math.cos(camAngle) * 5.85),
        focus: focus,
      );
    }
  }

  await animate(0.0);
  effectAnimators.add(animate);
}
