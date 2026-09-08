import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

double effectEase(double start, double end, double time) {
  final u = ((time - start) / (end - start)).clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

Future<void> setupInteractionStage(
    ThermionViewer viewer, String assetsDir, Vector3 eye, Vector3 focus,
    {bool shadows = true}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
      near: .1, far: 100, aspect: 1, focalLength: 35);
  await camera.lookAt(eye, focus: focus);
  await (await viewer.view.getScene()).setSkybox(
      await viewer.app.createColoredSkybox(r: .0005, g: .0007, b: .0012, a: 1));
  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 800);
  await enableVfxPost(viewer, bloomStrength: .12);
  await viewer.setShadowsEnabled(shadows);
  await viewer.addDirectLight(DirectLight.sun(
      direction: Vector3(-.5, -.8, -.4),
      intensity: 8000,
      castShadows: shadows));
}

Future<ThermionAsset> effectBox(ThermionViewer viewer, Vector3 center,
    Vector3 size, MaterialInstance material) async {
  final box = await viewer
      .createGeometry(GeometryUtils.cube(), materialInstances: [material]);
  await box
      .setTransform(Matrix4.translation(center) * Matrix4.diagonal3(size * .5));
  return box;
}
