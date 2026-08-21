import 'package:thermion_dart/thermion_dart.dart';

/// Post-processing showcase with high-contrast geometry and an emissive object
/// that make bloom, FXAA, and colour-grading changes easy to see.
Future<void> setupEffects(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  // Initial values match the web controls. The gallery can update them live.
  await viewer.setPostProcessing(true);
  await viewer.setAntiAliasing(false, true, false); // FXAA
  await viewer.setBloom(true, 0.30);

  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(0, 2.5, 7), focus: Vector3(0, 0.5, 0));

  await (await viewer.view.getScene()).setSkybox(
    await FilamentApp.instance!
        .createColoredSkybox(r: 0.025, g: 0.03, b: 0.04, a: 1.0),
  );
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -0.5)));
  await viewer.addDirectLight(
    DirectLight.point(
      color: const LinearColor(1.0, 0.9, 0.75),
      intensity: 2000000,
      falloffRadius: 8.0,
      position: Vector3(1.0, 2.8, 2.5),
      castShadows: false,
    ),
  );

  // The bright centre cube makes changes to bloom strength obvious.
  final emissive = await viewer.loadGltf(
    "$assetsDir/cube.glb",
    rebuildVertices: true,
  );
  await emissive.transformToUnitCube();
  await emissive.setTransform(Matrix4.translation(Vector3(-1.0, 0.5, 0)));
  final emissiveMaterial = await viewer.app.createUbershaderMaterial();
  await emissiveMaterial.setBaseColorFactor(0.15, 0.03, 0.01, 1.0);
  await emissiveMaterial.setMetallicFactor(0.0);
  await emissiveMaterial.setRoughnessFactor(0.35);
  await emissiveMaterial.setEmissiveFactor(1.0, 0.16, 0.03, 2.0);
  await emissive.setMaterialInstanceForAll(emissiveMaterial.materialInstance);

  // The remaining hard-edged geometry makes FXAA changes visible.
  final leftCube = await viewer.loadGltf("$assetsDir/cube.glb");
  await leftCube.transformToUnitCube();
  await leftCube.setTransform(
    Matrix4.translation(Vector3(-3.0, 0.5, 0)) *
        Matrix4.rotationY(0.35) *
        Matrix4.diagonal3(Vector3.all(0.8)),
  );
  final leftMaterial = await viewer.app.createUbershaderMaterial();
  await leftMaterial.setBaseColorFactor(0.9, 0.05, 0.03, 1.0);
  await leftMaterial.setMetallicFactor(0.0);
  await leftMaterial.setRoughnessFactor(0.65);
  await leftCube.setMaterialInstanceForAll(leftMaterial.materialInstance);

  // A low-roughness metallic sphere turns the point light above into a
  // concentrated specular highlight that can feed the bloom pass.
  final specular = await viewer.createGeometry(
    GeometryUtils.sphere(latitudeBands: 32, longitudeBands: 32),
  );
  await specular.setTransform(
    Matrix4.translation(Vector3(1.0, 0.5, 0)) *
        Matrix4.diagonal3(Vector3.all(0.8)),
  );
  final specularMaterial = await viewer.app.createUbershaderMaterial();
  await specularMaterial.setBaseColorFactor(0.03, 0.2, 1.0, 1.0);
  await specularMaterial.setMetallicFactor(1.0);
  await specularMaterial.setRoughnessFactor(0.05);
  await specular.setMaterialInstanceForAll(specularMaterial.materialInstance);
}
