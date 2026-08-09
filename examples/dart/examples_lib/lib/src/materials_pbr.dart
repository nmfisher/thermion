import 'package:thermion_dart/thermion_dart.dart';

/// Loads a cube and applies an [UbershaderMaterialInstance] with high metallic
/// and low roughness, to showcase PBR material properties under image-based
/// lighting.
///
/// Note: Filament's ubershader does not support transmission/volume/sheen/IOR
/// together with clearcoat, and the clearcoat uniform is not exposed on the
/// instance; this example uses the plain ubershader with metallic/roughness/
/// base-color only.
Future<void> setupMaterialsPbr(
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

  final asset = await viewer.loadGltf("$assetsDir/cube.glb");
  await asset.transformToUnitCube();

  final mat = await viewer.app.createUbershaderMaterial();
  await mat.setMetallicFactor(1.0);
  await mat.setRoughnessFactor(0.15);
  await mat.setBaseColorFactor(0.85, 0.5, 0.2, 1.0);

  await asset.setMaterialInstanceForAll(mat.materialInstance);

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, 0)));
}
