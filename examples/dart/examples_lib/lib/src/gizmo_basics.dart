import 'package:thermion_dart/thermion_dart.dart';

/// Loads a cube and attaches a translation [TransformationGizmo] to it.
///
/// NOTE: The original CLI example demonstrated multiple gizmo types
/// (translation, rotation) by capturing separate frames. This setup shows only
/// a single translation gizmo. DOM/canvas input wiring is intentionally omitted
/// -- the gallery provides flight-camera input separately.
Future<void> setupGizmoBasics(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final cubeAsset = await viewer.loadGltf("$assetsDir/cube.glb");
  await cubeAsset.transformToUnitCube();

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );
  await camera.lookAt(Vector3(2, 2, 2), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));

  final gizmo = TransformationGizmo(viewer);
  await gizmo.create(type: TransformationGizmoType.translation);
  await gizmo.attachTo(cubeAsset.entity);
}
