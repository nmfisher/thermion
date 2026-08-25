import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Hologram projection: the whole mesh renders as a translucent cyan shell
/// with a fresnel rim, fine upward-sweeping scanlines, a bright scanning
/// band, gated glitch shear with chromatic splitting, and flicker.
/// Unlit + transparent, so no lights are needed.
Future<void> setupHologram(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );
  await camera.lookAt(Vector3(1.6, 1.0, 1.6), focus: Vector3(0, 0, 0));

  await setDarkSkybox(viewer);

  final asset = await viewer.loadGltf("$assetsDir/BusterDrone/scene.gltf");
  await asset.transformToUnitCube();

  final hologram = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "hologram",
  );
  await hologram.setParameterFloat4("tintColor", 0.20, 0.85, 1.0, 1.0);
  await hologram.setParameterFloat("time", 2.2);
  await hologram.setParameterFloat("fresnelPower", 2.5);
  await hologram.setParameterFloat("fresnelStrength", 1.35);
  await hologram.setParameterFloat("scanlineCount", 70.0);
  await hologram.setParameterFloat("scanlineSpeed", 4.0);
  await hologram.setParameterFloat("glitchAmount", 0.09);

  await asset.setMaterialInstanceForAll(hologram);

  effectAnimators.add((t) async {
    await hologram.setParameterFloat("time", t);
  });
}
