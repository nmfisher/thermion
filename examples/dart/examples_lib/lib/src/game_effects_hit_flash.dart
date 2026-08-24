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

  // The flash replaces every material on the asset, so there are no lit
  // surfaces left - skip lights/IBL and keep the background dark so the
  // additive blend pops. (If you do want an IBL, load it BEFORE setting the
  // skybox: loadIbl installs its own skybox.)
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

  // Swap the flash on. A live timeline would snapshot the originals first
  // (getMaterialInstancesAsMap), animate progress 0 -> 1, then restore them
  // with setMaterialInstancesFromMap.
  await asset.setMaterialInstanceForAll(flash);
}
