import 'dart:math';

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
  // The source glTF's hidden display floor still contributes to its bounds,
  // so frame the drone directly instead of inheriting that oversized stage.
  await camera.lookAt(Vector3(0.82, 0.54, 0.82), focus: Vector3(0, 0, 0));

  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.28);

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

  // The source asset includes a large display floor (`Scheibe_Boden_0`).
  // Hide it so the projection reads as a floating subject rather than a
  // glowing or black rectangular stage.
  final displayFloor = await asset.getChildEntity("Scheibe_Boden_0");
  if (displayFloor != null) {
    await asset.setVisibilityLayer(displayFloor, VisibilityLayers.LAYER_3);
    await viewer.view.setLayerVisibility(VisibilityLayers.LAYER_3, false);
  }
  await asset.setMaterialInstanceForAll(hologram);

  // A hologram needs a visible emitter to sell the projection, not just a
  // cyan replacement material. This animated reticle anchors the drone in
  // the scene and adds a rotating acquisition sweep beneath it.
  final projector = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "hologram_projector",
  );
  await projector.setParameterFloat4("tintColor", 0.12, 0.78, 1.0, 1.0);
  await projector.setParameterFloat("time", 2.2);
  final emitter = await viewer.createGeometry(
    GeometryUtils.plane(width: 1.25, height: 1.25),
    materialInstances: [projector],
  );
  await emitter.setTransform(Matrix4.translation(Vector3(0, -0.56, 0)));

  effectAnimators.add((t) async {
    await hologram.setParameterFloat("time", t);
    await projector.setParameterFloat("time", t);
    final orbit = 0.08 * sin(t * 0.42);
    await camera.lookAt(
      Vector3(0.82 + orbit, 0.54 + 0.025 * sin(t * 0.7), 0.82 - orbit),
      focus: Vector3(0, -0.02, 0),
    );
  });
}
