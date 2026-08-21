import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

/// Materials and lighting showcase: a row of PBR spheres with varying
/// metallic/roughness/base-colour (matte, metal, satin, mirror), a wireframe
/// cube, and a flat-shaded cube, illuminated by three coloured point lights
/// orbiting the scene. The PBR parameters are driven onto the spheres via the
/// ubershader; the sphere geometry's winding is corrected in SphereGeometry so
/// back-face culling keeps the outward faces and diffuse light works.
Future<void> setupMaterialsAndLighting(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(0, 4.0, 11), focus: Vector3(0, 0, 0));

  await (await viewer.view.getScene()).setSkybox(
    await FilamentApp.instance!
        .createColoredSkybox(r: 0.18, g: 0.18, b: 0.18, a: 1.0),
  );
  // Dimmed IBL so the three coloured point lights read clearly against the
  // ambient fill — at higher intensities the image-based lighting washes out
  // their orbiting contribution.
  await viewer.loadIbl(
    "$assetsDir/materials_studio_ibl.ktx",
    intensity: 3000,
  );
  await viewer.setShadowsEnabled(true);
  await viewer.setShadowType(ShadowType.PCF);

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
          intensity: 1500000,
          falloffRadius: 12.0,
          position: Vector3(
            math.cos(angle) * lightRadius,
            lightHeight,
            math.sin(angle) * lightRadius,
          ),
          // The directional light below is the scene's shadow caster; these
          // moving lights are kept focused on the coloured illumination.
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

  // A single shadow caster keeps PCF shadows stable as the point lights move.
  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-1, -2, -1),
      intensity: 50000,
      castShadows: true,
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
    await sph.setCastShadows(true);
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
  await wireframe.setCastShadows(true);
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
  await flat.setCastShadows(true);

  final ground = await viewer.createGeometry(
    GeometryUtils.plane(width: 18, height: 14),
  );
  await ground.setTransform(Matrix4.translation(Vector3(0, -0.5, 0)));
  await ground.setCastShadows(false);
  await ground.setReceiveShadows(true);
  final groundMaterial = await viewer.app.createUbershaderMaterial();
  await groundMaterial.setMetallicFactor(0.0);
  await groundMaterial.setRoughnessFactor(1.0);
  await groundMaterial.setBaseColorFactor(0.8, 0.8, 0.8, 1.0);
  await ground.setMaterialInstanceForAll(groundMaterial.materialInstance);
}
