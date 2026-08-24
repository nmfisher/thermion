import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Hit flash: an impact ring expands from the hit point across the mesh
/// while a rim-weighted body flash decays - the classic "I got hit" read.
/// Driven by `progress` (0 = impact instant, 1 = finished) and `hitPoint`
/// (world space). Starts white-hot and settles into `flashColor`.
///
/// The flash is a temporary material-instance swap: snapshot the asset's
/// original instances, swap in the flash instance, animate `progress`
/// 0 -> 1, then restore. For the headless still the swap is left at
/// mid-flash with the ring mid-expansion.
Future<void> setupHitFlash(
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
  await camera.lookAt(Vector3(0, 0.1, 1.6), focus: Vector3(0, 0, 0));

  // The flash swaps out every material on the asset, but between flashes
  // the normal PBR look should show - so light the scene and keep the
  // background dark for the additive blend. A dim directional light only
  // (no IBL): the default-env IBL is bright enough to blow the helmet out
  // to pure white, which leaves no headroom for the additive flash and
  // hides the shockwave ring entirely.
  await viewer.addDirectLight(DirectLight.sun(
    direction: Vector3(0, -1, -0.4),
    intensity: 9000,
    castShadows: false,
  ));
  await setDarkSkybox(viewer);

  final asset = await viewer.loadGltf("$assetsDir/FlightHelmet/FlightHelmet.gltf");
  await asset.transformToUnitCube();

  final flash = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "hit_flash",
  );
  await flash.setParameterFloat4("flashColor", 1.0, 0.36, 0.1, 1.0);
  await flash.setParameterFloat3("hitPoint", 0.05, 0.28, 0.42);
  await flash.setParameterFloat("progress", 0.33);

  // A hit every 2.4s: swap the flash on, animate progress 0 -> 1 over
  // 0.55s (with the impact point rotating through a few spots on the
  // camera-facing side), then restore the original PBR materials.
  final originals = await asset.getMaterialInstancesAsMap();
  final hitPoints = [
    Vector3(0.05, 0.28, 0.42),
    Vector3(-0.18, 0.05, 0.38),
    Vector3(0.12, -0.22, 0.30),
  ];
  const flashDuration = 0.55;
  const hitPeriod = 2.4;
  var flashed = false;
  var hitIndex = 0;
  effectAnimators.add((t) async {
    final cycle = t % hitPeriod;
    if (cycle < flashDuration) {
      if (!flashed) {
        flashed = true;
        hitIndex = (hitIndex + 1) % hitPoints.length;
        final p = hitPoints[hitIndex];
        await flash.setParameterFloat3("hitPoint", p.x, p.y, p.z);
        await asset.setMaterialInstanceForAll(flash);
      }
      await flash.setParameterFloat("progress", cycle / flashDuration);
    } else if (flashed) {
      await asset.setMaterialInstancesFromMap(originals);
      flashed = false;
    }
  });
  await asset.setMaterialInstanceForAll(flash);
}
