import 'package:thermion_dart/thermion_dart.dart';

/// Loads a textured model (FlightHelmet) to demonstrate rich PBR texturing.
///
/// NOTE: The original CLI example created textures programmatically from raw
/// PNG/KTX2 bytes using `decodeImage`, `createTexture`, and `loadKtx2`. Those
/// APIs require raw file access (`dart:io`) which is not available in the
/// shared setup context. This setup uses a pre-textured glTF model instead.
Future<void> setupTextureFromScratch(
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
  await camera.lookAt(Vector3(2, 2, 2), focus: Vector3(0, 0, 0));

  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, 0)));

  await viewer.loadGltf("$assetsDir/FlightHelmet/FlightHelmet.gltf");
}
