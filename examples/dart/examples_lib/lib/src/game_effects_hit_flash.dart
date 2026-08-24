import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Hit flash: the whole mesh pulses bright (strongest at rim/silhouette
/// edges) then fades out. Driven by the `progress` uniform, 0 = full flash,
/// 1 = finished.
///
/// The flash is a temporary material-instance swap: snapshot the asset's
/// original instances, swap in the flash instance, animate `progress`
/// 0 -> 1, then restore. For the headless still the swap is simply left at
/// mid-flash (progress = 0.45).
///
/// Live timeline (for a windowed runner driving `render()`):
/// ```dart
/// final clock = EffectClock();
/// await FilamentApp.instance!.registerRequestFrameHook(() async {
///   clock.tick();
///   await flash.setParameterFloat("progress", clock.elapsedTime / 0.3);
/// });
/// // ...after the flash elapses, restore the snapshot and unregister.
/// ```
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
  // background dark for the additive blend. (loadIbl installs its own
  // skybox, so it must run BEFORE setDarkSkybox.)
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -0.4)));
  await setDarkSkybox(viewer);

  final asset = await viewer.loadGltf("$assetsDir/FlightHelmet/FlightHelmet.gltf");
  await asset.transformToUnitCube();

  final flash = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "hit_flash",
  );
  await flash.setParameterFloat4("flashColor", 1.0, 0.3, 0.1, 1.0);
  await flash.setParameterFloat("progress", 0.45);

  // A hit every 2.4s: swap the flash on, animate progress 0 -> 1 over
  // 0.55s, then restore the original PBR materials until the next hit.
  // (Still captures use the mid-flash state left by setup.)
  final originals = await asset.getMaterialInstancesAsMap();
  const flashDuration = 0.55;
  const hitPeriod = 2.4;
  var flashed = false;
  effectAnimators.add((t) async {
    final cycle = t % hitPeriod;
    if (cycle < flashDuration) {
      if (!flashed) {
        await asset.setMaterialInstanceForAll(flash);
        flashed = true;
      }
      await flash.setParameterFloat("progress", cycle / flashDuration);
    } else if (flashed) {
      await asset.setMaterialInstancesFromMap(originals);
      flashed = false;
    }
  });
  await asset.setMaterialInstanceForAll(flash);
}
