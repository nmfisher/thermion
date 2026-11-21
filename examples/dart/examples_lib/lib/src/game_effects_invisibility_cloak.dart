import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Active optical camouflage with real screen-space background refraction,
/// hexagonal metamaterial phase-transition sweep, and periodic glitch ripples
/// against an illuminated sci-fi security backdrop.
Future<void> setupInvisibilityCloak(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: 1,
    focalLength: 32,
  );
  await camera.lookAt(Vector3(1.15, 0.38, 2.25), focus: Vector3(0, -0.02, 0));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 18000);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.20);

  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-0.45, -0.68, -0.58),
      color: const LinearColor(0.88, 0.94, 1.0),
      intensity: 62000,
    ),
  );

  // Illuminated sci-fi security bulkhead behind the helmet so optical refraction
  // visibly bends and warps crisp background stripes & panels!
  final wallMat = await viewer.app.createUbershaderMaterial();
  await wallMat.setBaseColorFactor(0.032, 0.044, 0.068, 1.0);
  await wallMat.setMetallicFactor(0.45);
  await wallMat.setRoughnessFactor(0.36);
  await effectBox(viewer, Vector3(0, 0.1, -1.35), Vector3(4.6, 3.2, 0.12),
      wallMat.materialInstance);

  final floorMat = await viewer.app.createUbershaderMaterial();
  await floorMat.setBaseColorFactor(0.020, 0.028, 0.042, 1.0);
  await floorMat.setMetallicFactor(0.40);
  await floorMat.setRoughnessFactor(0.28);
  await effectBox(viewer, Vector3(0, -0.62, -0.2), Vector3(4.8, 0.12, 3.6),
      floorMat.materialInstance);

  final stripeCyan = await viewer.app.createUbershaderMaterial();
  await stripeCyan.setBaseColorFactor(0.06, 0.45, 0.85, 1.0);
  await stripeCyan.materialInstance
      .setParameterFloat4('emissiveFactor', 0.18, 0.72, 1.0, 0.85);
  final stripeAmber = await viewer.app.createUbershaderMaterial();
  await stripeAmber.setBaseColorFactor(0.85, 0.42, 0.08, 1.0);
  await stripeAmber.materialInstance
      .setParameterFloat4('emissiveFactor', 1.0, 0.48, 0.10, 0.80);

  for (var i = -4; i <= 4; i++) {
    final y = i * 0.24;
    final mat = i.isEven ? stripeCyan.materialInstance : stripeAmber.materialInstance;
    await effectBox(
      viewer,
      Vector3(-0.35, y, -1.26),
      Vector3(3.8, 0.026, 0.03),
      mat,
    );
  }
  for (var i = -5; i <= 5; i++) {
    await effectBox(
      viewer,
      Vector3(-0.35 + i * 0.36, 0.1, -1.27),
      Vector3(0.035, 2.6, 0.025),
      wallMat.materialInstance,
    );
  }

  final asset =
      await viewer.loadGltf('$assetsDir/FlightHelmet/FlightHelmet.gltf');
  await asset.transformToUnitCube();
  final cloak = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'invisibility_cloak',
  );
  await cloak.setParameterFloat('time', 0.45);
  await cloak.setParameterFloat('disruption', 0.45);
  await asset.setMaterialInstanceForAll(cloak);
  effectAnimators.add((t) async {
    final disruption =
        0.28 + 0.72 * math.pow(0.5 + 0.5 * math.sin(t * 2.1), 4).toDouble();
    await cloak.setParameterFloat('time', t + 0.45);
    await cloak.setParameterFloat('disruption', disruption);
  });
}
