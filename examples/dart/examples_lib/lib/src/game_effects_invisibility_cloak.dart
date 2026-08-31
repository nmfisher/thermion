import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Active camouflage with a restrained near-invisible body, chromatic fresnel
/// silhouette, local refraction shimmer, scan faults, and periodic disruption.
Future<void> setupInvisibilityCloak(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: 1,
    focalLength: 31,
  );
  await camera.lookAt(Vector3(1.55, 0.7, 2.35), focus: Vector3(0, 0, 0));
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.24);
  final asset =
      await viewer.loadGltf('$assetsDir/FlightHelmet/FlightHelmet.gltf');
  await asset.transformToUnitCube();
  final cloak = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'invisibility_cloak',
  );
  await cloak.setParameterFloat('time', 2.15);
  await cloak.setParameterFloat('disruption', 0.55);
  await asset.setMaterialInstanceForAll(cloak);
  effectAnimators.add((t) async {
    final disruption =
        math.pow(math.max(0.0, math.sin(t * 1.42)), 12).toDouble();
    await cloak.setParameterFloat('time', t);
    await cloak.setParameterFloat('disruption', 0.18 + disruption * 0.82);
  });
}
