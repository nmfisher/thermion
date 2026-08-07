import 'package:thermion_dart/thermion_dart.dart';

/// Lighting showcase: a shadow-casting directional sun, image-based lighting,
/// a skybox, and a warm point light -- all acting on a cube floating above a
/// shadow-receiving ground plane.
///
/// Absorbs lighting_setup + skybox_and_background + shadows.
Future<void> setupLighting(
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
  await camera.lookAt(Vector3(4, 3, 4), focus: Vector3(0, 0.5, 0));

  // Environment.
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  // Shadow-casting key light + a warm fill point light.
  await viewer.addDirectLight(
    DirectLight.sun(castShadows: true, direction: Vector3(-1, -2, -1)),
  );
  await viewer.addDirectLight(
    DirectLight.point(
      color: const LinearColor(1.0, 0.8, 0.6),
      intensity: 80000,
      position: Vector3(3, 3, 3),
      castShadows: false,
    ),
  );
  await viewer.setShadowsEnabled(true);
  await viewer.setShadowType(ShadowType.PCF);

  // Cube floating above a shadow-receiving ground.
  final cube = await viewer.loadGltf("$assetsDir/cube.glb");
  await cube.transformToUnitCube();
  await cube.setTransform(Matrix4.translation(Vector3(0, 0.6, 0)));

  final ground = await viewer.createGeometry(
    GeometryUtils.plane(width: 12, height: 12),
  );
  await ground.setReceiveShadows(true);
}
