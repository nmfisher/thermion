import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Smooth tubular trefoil torus-knot sculpture with thin ribbons and thick
/// crossings that dramatically showcase Filament's `subsurface` transmission!
Geometry _trefoilKnot({int tubularSegments = 160, int radialSegments = 28}) {
  Vector3 curve(double t) {
    final x = math.sin(t) + 2.0 * math.sin(2.0 * t);
    final y = math.cos(t) - 2.0 * math.cos(2.0 * t);
    final z = -math.sin(3.0 * t) * 1.15;
    return Vector3(x, y, z) * 0.185;
  }

  final vertCount = (tubularSegments + 1) * (radialSegments + 1);
  final vertices = Float32List(vertCount * 3);
  final normals = Float32List(vertCount * 3);
  final uvs = Float32List(vertCount * 2);
  final indices = <int>[];

  for (var i = 0; i <= tubularSegments; i++) {
    final u = i / tubularSegments;
    final t = u * math.pi * 2.0;
    final p0 = curve(t);
    final p1 = curve(t + 0.005);
    final tangent = (p1 - p0)..normalize();
    final up = Vector3(0, 0, 1);
    var normal = tangent.cross(up);
    if (normal.length2 < 1e-5) normal = tangent.cross(Vector3(1, 0, 0));
    normal.normalize();
    final binormal = tangent.cross(normal)..normalize();
    final tubeR = 0.125 + 0.022 * math.sin(t * 3.0);

    for (var j = 0; j <= radialSegments; j++) {
      final v = j / radialSegments;
      final phi = v * math.pi * 2.0;
      final dir = normal * math.cos(phi) + binormal * math.sin(phi);
      final pos = p0 + dir * tubeR;
      final idx = i * (radialSegments + 1) + j;
      vertices[idx * 3] = pos.x;
      vertices[idx * 3 + 1] = pos.y;
      vertices[idx * 3 + 2] = pos.z;
      normals[idx * 3] = dir.x;
      normals[idx * 3 + 1] = dir.y;
      normals[idx * 3 + 2] = dir.z;
      uvs[idx * 2] = u;
      uvs[idx * 2 + 1] = v;
    }
  }

  for (var i = 0; i < tubularSegments; i++) {
    for (var j = 0; j < radialSegments; j++) {
      final a = i * (radialSegments + 1) + j;
      final b = a + (radialSegments + 1);
      indices.addAll([a, b, a + 1, a + 1, b, b + 1]);
    }
  }
  return Geometry(vertices, indices, normals: normals, uvs: uvs);
}

/// Showcases Filament's `shadingModel: subsurface` across three museum plinths:
/// Imperial emerald jade (left), warm sculpted beeswax/coral knot (center), and
/// fossilized Baltic amber with deep parallax bubble inclusions (right), lit by
/// an orbiting high-intensity rim/backlight.
Future<void> setupSubsurface(
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
  final focus = Vector3(0, 1.18, 0);
  await camera.lookAt(Vector3(0.4, 2.35, 7.6), focus: focus);
  effectCameraControls = EffectCameraControls(focus: focus);

  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 6500);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.16);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);

  // Restrained front-key fill so the orbiting rear spotlight drives dramatic
  // subsurface light bleed through thin edges!
  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-0.35, -0.75, -0.55),
      color: const LinearColor(0.92, 0.95, 1.0),
      intensity: 16000,
      castShadows: true,
    ),
  );

  final backLight = await viewer.addDirectLight(
    DirectLight.point(
      position: Vector3(0.0, 1.35, -0.95),
      color: const LinearColor(1.0, 0.94, 0.84),
      intensity: 420000,
      falloffRadius: 11.0,
    ),
  );

  // Small glowing orb visualizing the orbiting backlight behind the sculptures!
  final bulbMat = await viewer.app.createUbershaderMaterial();
  await bulbMat.setBaseColorFactor(1.0, 0.92, 0.78, 1.0);
  await bulbMat.materialInstance
      .setParameterFloat4('emissiveFactor', 1.0, 0.88, 0.68, 0.95);
  final bulb = await viewer.createGeometry(
    GeometryUtils.sphere(latitudeBands: 20, longitudeBands: 28),
    materialInstances: [bulbMat.materialInstance],
  );
  await bulb.setCastShadows(false);

  final plinthMat = await viewer.app.createUbershaderMaterial();
  await plinthMat.setBaseColorFactor(0.020, 0.025, 0.034, 1.0);
  await plinthMat.setMetallicFactor(0.35);
  await plinthMat.setRoughnessFactor(0.28);

  final floor = await effectBox(
      viewer, Vector3(0, -0.1, 0), Vector3(8.2, 0.2, 4.4), plinthMat.materialInstance);
  await floor.setReceiveShadows(true);

  final instances = <MaterialInstance>[];
  Future<MaterialInstance> makeMat(double preset) async {
    final m = await loadEffectMaterial(
      viewer,
      assetsDir: assetsDir,
      name: 'subsurface_jade',
    );
    await m.setParameterFloat('time', 0.0);
    await m.setParameterFloat('preset', preset);
    await m.setParameterFloat('thicknessScale', 0.72);
    await m.setParameterFloat('scatterStrength', 1.0);
    await m.setParameterFloat('roughness', 0.14);
    instances.add(m);
    return m;
  }

  for (final x in [-2.05, 0.0, 2.05]) {
    final p = await effectBox(
      viewer,
      Vector3(x, 0.24, 0),
      Vector3(1.55, 0.48, 1.55),
      plinthMat.materialInstance,
    );
    await p.setReceiveShadows(true);
  }

  // 1. Left: Carved Imperial Emerald Jade FlightHelmet (scaled to match knot & amber height!)
  final jadeMat = await makeMat(0.0);
  final helmet =
      await viewer.loadGltf('$assetsDir/FlightHelmet/FlightHelmet.gltf');
  await helmet.setMaterialInstanceForAll(jadeMat);
  await helmet.setTransform(
    Matrix4.translation(Vector3(-2.05, 0.48, 0)) *
        Matrix4.rotationY(0.35) *
        Matrix4.diagonal3(Vector3.all(2.65)),
  );

  // 2. Center: Warm Translucent Beeswax / Coral Trefoil Knot
  final waxMat = await makeMat(1.0);
  final knot = await viewer.createGeometry(
    _trefoilKnot(),
    materialInstances: [waxMat],
  );
  await knot.setTransform(
    Matrix4.translation(Vector3(0.0, 1.22, 0)) *
        Matrix4.diagonal3(Vector3.all(0.95)),
  );
  await knot.setCastShadows(true);
  await knot.setReceiveShadows(true);

  // 3. Right: Polished Baltic Amber Cabochon Monolith with Parallax Bubbles
  final amberMat = await makeMat(2.0);
  final amber = await viewer.createGeometry(
    GeometryUtils.sphere(latitudeBands: 64, longitudeBands: 96),
    materialInstances: [amberMat],
  );
  await amber.setTransform(
    Matrix4.translation(Vector3(2.05, 1.18, 0)) *
        Matrix4.rotationZ(-0.10) *
        Matrix4.diagonal3(Vector3(0.52, 0.72, 0.42)),
  );
  await amber.setCastShadows(true);
  await amber.setReceiveShadows(true);

  Future<void> shared(String name, double v) async {
    for (final m in instances) {
      await m.setParameterFloat(name, v);
    }
  }

  effectSliders.addAll([
    EffectSlider(
      'Optical thickness',
      min: 0.15,
      max: 1.5,
      initialValue: 0.72,
      setValue: (v) => shared('thicknessScale', v),
    ),
    EffectSlider(
      'Scatter intensity',
      min: 0.0,
      max: 1.5,
      initialValue: 1.0,
      setValue: (v) => shared('scatterStrength', v),
    ),
    EffectSlider(
      'Surface roughness',
      min: 0.04,
      max: 0.65,
      initialValue: 0.14,
      setValue: (v) => shared('roughness', v),
    ),
  ]);

  Future<void> animate(double t) async {
    await shared('time', t);
    // Sweep the bright backlight closely behind all three sculptures!
    final lx = 2.45 * math.sin(t * math.pi * 2 / 6.0);
    final ly = 1.28 + 0.18 * math.cos(t * math.pi * 2 / 3.0);
    const lz = -0.88;
    for (final m in instances) {
      await m.setParameterFloat3('lightPos', lx, ly, lz);
    }
    viewer.app.lightManager.setPosition(backLight, lx, ly, lz);
    await bulb.setTransform(
      Matrix4.translation(Vector3(lx, ly, lz)) *
          Matrix4.diagonal3(Vector3.all(0.075)),
    );
    await knot.setTransform(
      Matrix4.translation(Vector3(0.0, 1.22, 0)) *
          Matrix4.rotationY(t * math.pi * 2 / 6.0) *
          Matrix4.diagonal3(Vector3.all(0.95)),
    );
  }

  await animate(0.0);
  effectAnimators.add(animate);
}
