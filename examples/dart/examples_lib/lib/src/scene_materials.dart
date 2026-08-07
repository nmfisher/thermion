import 'package:thermion_dart/thermion_dart.dart';

/// Materials showcase: a row of PBR spheres with varying metallic/roughness/
/// base-colour (matte, metal, satin, mirror), a wireframe cube, and a
/// flat-shaded cube. The PBR parameters are driven onto the spheres via the
/// ubershader; the sphere geometry's winding is corrected in SphereGeometry so
/// back-face culling keeps the outward faces and diffuse light works.
Future<void> setupMaterials(
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
  await camera.lookAt(Vector3(0, 2.5, 11), focus: Vector3(0, 0.5, 0));

  await viewer.setBackgroundColor(0.18, 0.18, 0.18, 1.0);
  await viewer.loadIbl("$assetsDir/materials_studio_ibl.ktx");
  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(0, -0.6, -1),
      intensity: 50000,
      castShadows: false,
    ),
  );

  // PBR sphere row: (metallic, roughness, base-colour).
  final configs = <(double, double, (double, double, double))>[
    (0.0, 0.9, (0.9, 0.2, 0.2)), // matte red plastic
    (1.0, 0.15, (0.85, 0.5, 0.2)), // brushed metal
    (0.0, 0.45, (0.2, 0.5, 0.9)), // satin blue
    (1.0, 0.05, (0.9, 0.9, 0.95)), // polished chrome
  ];
  for (var i = 0; i < configs.length; i++) {
    final (metal, rough, (r, g, b)) = configs[i];
    final sph = await viewer.createGeometry(
      GeometryUtils.sphere(latitudeBands: 32, longitudeBands: 32),
    );
    await sph
        .setTransform(Matrix4.translation(Vector3(-3.6 + i * 2.4, 0.5, 0)));
    final mat = await viewer.app.createUbershaderMaterial();
    await mat.setMetallicFactor(metal);
    await mat.setRoughnessFactor(rough);
    await mat.setBaseColorFactor(r, g, b, 1.0);
    await sph.setMaterialInstanceForAll(mat.materialInstance);
  }

  // Wireframe cube, far left.
  final wireframe =
      await viewer.loadGltf("$assetsDir/cube.glb", rebuildVertices: true);
  await wireframe.transformToUnitCube();
  await wireframe.setTransform(
    Matrix4.translation(Vector3(-6.2, 0.5, 0)) *
        Matrix4.diagonal3(Vector3.all(0.8)),
  );
  final wireMat = await viewer.app.createWireframeMaterialInstance();
  await wireMat.setEdgeColor(0.4, 0.8, 1.0, 1.0);
  await wireMat.setFaceColor(0.05, 0.05, 0.08, 1.0);
  await wireMat.setEdgeWidth(1.0);
  await wireframe.setMaterialInstanceForAll(wireMat.materialInstance);

  // Flat-shaded cube, far right.
  final flat =
      await viewer.loadGltf("$assetsDir/cube.glb", rebuildVertices: true);
  await flat.transformToUnitCube();
  await flat.setTransform(
    Matrix4.translation(Vector3(6.2, 0.5, 0)) *
        Matrix4.diagonal3(Vector3.all(0.8)),
  );
  await flat.setFlatShading(true);
}
