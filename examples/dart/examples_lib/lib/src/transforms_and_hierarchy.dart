import 'package:thermion_dart/thermion_dart.dart';

/// Loads two cubes: a parent and a child. The child is offset from the parent
/// and then parented via [FilamentApp.setParent], so moving the parent also
/// moves the child -- demonstrating scene-graph hierarchy.
Future<void> setupTransformsAndHierarchy(
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

  final parent = await viewer.loadGltf("$assetsDir/cube.glb");
  await parent.transformToUnitCube();

  final child = await viewer.loadGltf("$assetsDir/cube.glb");
  await child.transformToUnitCube();
  await child.setTransform(Matrix4.translation(Vector3(1.0, 0.0, 0.0)));

  // Parent the child to the parent.
  await viewer.app.setParent(child.entity, parent.entity);

  // Move the parent -- the child follows.
  await parent.setTransform(Matrix4.translation(Vector3(-1.0, 0.0, 0.0)));
}
