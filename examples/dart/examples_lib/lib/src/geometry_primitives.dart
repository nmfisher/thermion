import 'package:thermion_dart/thermion_dart.dart';

/// Creates the five procedural geometry primitives (cube, sphere, cylinder,
/// conic, plane) from [GeometryUtils] and arranges them in a row.
Future<void> setupGeometryPrimitives(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);
  await camera.lookAt(Vector3(0, 4, 8), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  final cube = await viewer.createGeometry(GeometryUtils.cube());
  await cube.setTransform(Matrix4.translation(Vector3(-4, 0, 0)));

  final sphere = await viewer.createGeometry(GeometryUtils.sphere());
  await sphere.setTransform(Matrix4.translation(Vector3(-2, 0, 0)));

  final cylinder = await viewer.createGeometry(GeometryUtils.cylinder(uvs: false));
  await cylinder.setTransform(Matrix4.translation(Vector3(0, 0, 0)));

  final conic = await viewer.createGeometry(GeometryUtils.conic(uvs: false));
  await conic.setTransform(Matrix4.translation(Vector3(2, 0, 0)));

  final plane = await viewer.createGeometry(GeometryUtils.plane());
  await plane.setTransform(Matrix4.translation(Vector3(4, 0, 0)));
}
