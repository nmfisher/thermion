import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

/// Materials showcase: a row of PBR spheres with varying metallic/roughness/
/// base-colour (matte, metal, satin, mirror), a wireframe cube, and a
/// flat-shaded cube, illuminated by three coloured point lights orbiting the
/// scene. The PBR parameters are driven onto the spheres via the ubershader;
/// the sphere geometry's winding is corrected in SphereGeometry so back-face
/// culling keeps the outward faces and diffuse light works.
Future<void> setupMaterials(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(0, 2.5, 11), focus: Vector3(0, 0.5, 0));

  await viewer.setBackgroundColor(0.18, 0.18, 0.18, 1.0);
  await viewer.loadIbl(
    "$assetsDir/materials_studio_ibl.ktx",
    intensity: 10000,
  );

  const lightColors = [
    LinearColor(1.0, 0.12, 0.05),
    LinearColor(0.05, 0.35, 1.0),
    LinearColor(0.12, 1.0, 0.25),
  ];
  const lightRadius = 6.0;
  const lightHeight = 3.0;
  final lights = <ThermionEntity>[];
  for (var i = 0; i < lightColors.length; i++) {
    final angle = i * 2 * math.pi / lightColors.length;
    lights.add(
      await viewer.addDirectLight(
        DirectLight.point(
          color: lightColors[i],
          intensity: 150000,
          falloffRadius: 12.0,
          position: Vector3(
            math.cos(angle) * lightRadius,
            lightHeight,
            math.sin(angle) * lightRadius,
          ),
          castShadows: false,
        ),
      ),
    );
  }

  final lightClock = Stopwatch()..start();
  await viewer.app.registerRequestFrameHook(() async {
    final rotation = lightClock.elapsedMicroseconds / 1000000 * 0.45;
    for (var i = 0; i < lights.length; i++) {
      final angle = rotation + i * 2 * math.pi / lights.length;
      await viewer.setLightPosition(
        lights[i],
        math.cos(angle) * lightRadius,
        lightHeight,
        math.sin(angle) * lightRadius,
      );
    }
  });

  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(0, -1, -0.4),
      intensity: 15000,
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
