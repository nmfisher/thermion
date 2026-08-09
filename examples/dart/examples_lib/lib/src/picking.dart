import 'package:thermion_dart/thermion_dart.dart';

/// Creates three instanced cubes as pickable geometry for the picking concept.
///
/// NOTE: The original CLI example performed actual pick calls and printed
/// results. Pick interaction is platform-specific and intentionally omitted
/// here -- the gallery handles input separately.
Future<void> setupPicking(
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
  await camera.lookAt(Vector3(3, 3, 3), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  final asset =
      await viewer.loadGltf("$assetsDir/cube.glb", initialInstances: 3);
  await asset.transformToUnitCube();

  final i0 = await asset.getInstance(0);
  await i0.setTransform(Matrix4.translation(Vector3(-1.5, 0, 0)));

  final i1 = await asset.getInstance(1);
  await i1.setTransform(Matrix4.translation(Vector3(0, 0, 0)));

  final i2 = await asset.getInstance(2);
  await i2.setTransform(Matrix4.translation(Vector3(1.5, 0, 0)));
}
