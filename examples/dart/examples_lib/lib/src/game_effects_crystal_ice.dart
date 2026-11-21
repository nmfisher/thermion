import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Faceted ice with spectral edge separation, animated inner volume, and
/// emissive branching fissures. A coarse hero shell makes its planes readable.
Future<void> setupCrystalIce(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: 1,
    focalLength: 34,
  );
  await camera.lookAt(Vector3(2.15, 1.25, 3.25), focus: Vector3(0, 0.15, 0));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 16000);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.20);
  await viewer.setShadowsEnabled(true);

  final crystal = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'crystal_ice',
  );
  await crystal.setParameterFloat('time', 1.8);
  await crystal.setParameterFloat4('tint', 0.06, 0.42, 0.82, 0.92);
  final shardGeometry = crystalShard(radius: 0.34, length: 1.0);
  final shardTransforms = <Matrix4>[
    Matrix4.translation(Vector3(0, -1.12, 0)) *
        Matrix4.rotationY(0.32) *
        Matrix4.diagonal3(Vector3(0.88, 2.35, 0.88)),
    Matrix4.translation(Vector3(-0.48, -1.05, 0.05)) *
        Matrix4.rotationZ(-0.26) *
        Matrix4.rotationY(-0.42) *
        Matrix4.diagonal3(Vector3(0.66, 1.58, 0.66)),
    Matrix4.translation(Vector3(0.47, -1.05, 0.08)) *
        Matrix4.rotationZ(0.31) *
        Matrix4.rotationY(0.77) *
        Matrix4.diagonal3(Vector3(0.61, 1.48, 0.61)),
    Matrix4.translation(Vector3(-0.2, -1.08, 0.38)) *
        Matrix4.rotationX(-0.23) *
        Matrix4.diagonal3(Vector3(0.48, 1.22, 0.48)),
    Matrix4.translation(Vector3(0.22, -1.08, -0.32)) *
        Matrix4.rotationX(0.24) *
        Matrix4.diagonal3(Vector3(0.44, 1.12, 0.44)),
  ];
  for (final transform in shardTransforms) {
    final shard = await viewer.createGeometry(
      shardGeometry,
      materialInstances: [crystal],
    );
    await shard.setTransform(transform);
  }

  final groundMaterial = await viewer.app.createUbershaderMaterial();
  await groundMaterial.setBaseColorFactor(0.014, 0.024, 0.042, 1.0);
  await groundMaterial.setMetallicFactor(0.08);
  await groundMaterial.setRoughnessFactor(0.16);
  final ground = await viewer.createGeometry(
    GeometryUtils.plane(width: 9, height: 9),
    materialInstances: [groundMaterial.materialInstance],
  );
  await ground.setTransform(Matrix4.translation(Vector3(0, -1.22, 0)));
  await ground.setReceiveShadows(true);
  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-0.55, -0.68, -0.48),
      color: const LinearColor(0.88, 0.95, 1.0),
      intensity: 68000,
      castShadows: true,
    ),
  );
  await viewer.addDirectLight(
    DirectLight.point(
      position: Vector3(-1.8, 1.6, -2.2),
      color: const LinearColor(0.28, 0.72, 1.0),
      intensity: 95000,
      falloffRadius: 10.0,
    ),
  );
  const baseAngle = 0.5804; // atan2(2.15, 3.25), radius ~ 3.897
  const orbitRadius = 3.897;
  effectAnimators.add((t) async {
    await crystal.setParameterFloat('time', t);
    if (!effectCameraUserControlled) {
      final angle = baseAngle + 0.52 * math.sin(t * math.pi * 2 / 6.0);
      final elev = 1.25 + 0.18 * math.sin(t * math.pi * 2 / 6.0);
      await camera.lookAt(
        Vector3(
            math.sin(angle) * orbitRadius, elev, math.cos(angle) * orbitRadius),
        focus: Vector3(0, 0.15, 0),
      );
    }
  });
}
