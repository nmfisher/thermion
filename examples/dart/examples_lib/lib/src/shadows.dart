import 'package:thermion_dart/thermion_dart.dart';

/// A cube floating above a ground plane, lit by a shadow-casting sun with PCF
/// shadows enabled.
Future<void> setupShadows(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(near: 0.1, far: 100.0, aspect: 1.0, focalLength: 28.0);
  await camera.lookAt(Vector3(3, 3, 3), focus: Vector3(0, 0, 0));

  final cubeAsset = await viewer.loadGltf("$assetsDir/cube.glb");
  await cubeAsset.transformToUnitCube();
  await cubeAsset.setTransform(Matrix4.translation(Vector3(0, 0.5, 0)));

  final groundAsset =
      await viewer.createGeometry(GeometryUtils.plane(width: 10, height: 10));
  await groundAsset.setReceiveShadows(true);

  await viewer.addDirectLight(
    DirectLight.sun(castShadows: true, direction: Vector3(-1, -2, -1)),
  );
  await viewer.setShadowsEnabled(true);
  await viewer.setShadowType(ShadowType.PCF);
}
