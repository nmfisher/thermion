import 'package:thermion_dart/thermion_dart.dart';

/// Loads a cube as a visual backdrop for the input-handler concept.
///
/// NOTE: The original CLI example demonstrated the [InputHandler] API by
/// dispatching synthetic mouse/scroll/key events. Actual DOM/canvas input
/// wiring is platform-specific and intentionally omitted here -- the gallery
/// provides flight-camera input separately.
Future<void> setupInputHandlers(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final asset = await viewer.loadGltf("$assetsDir/cube.glb");
  await asset.transformToUnitCube();

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );
  await camera.lookAt(Vector3(1.5, 1.5, 1.5), focus: Vector3(0, 0, 0));
}
