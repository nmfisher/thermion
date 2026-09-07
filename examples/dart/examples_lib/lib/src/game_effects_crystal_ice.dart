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
  await camera.lookAt(Vector3(2.25, 1.35, 3.4), focus: Vector3(0, 0.18, 0));
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.24);

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
  await groundMaterial.setBaseColorFactor(0.018, 0.028, 0.055, 1.0);
  await groundMaterial.setMetallicFactor(0.15);
  await groundMaterial.setRoughnessFactor(0.22);
  final ground = await viewer.createGeometry(
    GeometryUtils.plane(width: 7, height: 7),
    materialInstances: [groundMaterial.materialInstance],
  );
  await ground.setTransform(Matrix4.translation(Vector3(0, -1.26, 0)));
  await viewer.addDirectLight(
    DirectLight.sun(direction: Vector3(-0.5, -0.7, -0.45), intensity: 80000),
  );
  effectAnimators.add((t) async {
    await crystal.setParameterFloat('time', t);
  });
}
