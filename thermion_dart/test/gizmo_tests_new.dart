// ignore_for_file: unused_local_variable
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';
import '../lib/src/utils/src/gizmos.dart' as custom_gizmo;

void main() async {
  final testHelper = TestHelper("gizmo");
  await testHelper.setup();

  test('create and render translation gizmo', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(10, 10, 10))
        .addCube(unlit: true, color: kRed, createUbershader: true)
        .execute((result) async {
      // Create the gizmo
      final gizmo = custom_gizmo.TransformationGizmo(result.viewer);
      await gizmo.create(
          type: custom_gizmo.TransformationGizmoType.translation);

      // Update gizmo with camera position for proper scaling
      final camera = await result.viewer.getActiveCamera();
      final cameraPos = Vector3(3, 3, 3);
      await gizmo.update(cameraPosition: cameraPos);

      await testHelper.capture(
          result.viewer.view, "gizmo_translation_standalone");
    });
  });

  test('create and render rotation gizmo', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(10, 10, 10))
        .addCube(unlit: true, color: kRed, createUbershader: true)
        .execute((result) async {
      // Create the gizmo
      final gizmo = custom_gizmo.TransformationGizmo(result.viewer);
      await gizmo.create(type: custom_gizmo.TransformationGizmoType.rotation);

      // Update gizmo with camera position for proper scaling
      final camera = await result.viewer.getActiveCamera();
      final cameraPos = Vector3(3, 3, 3);
      await gizmo.update(cameraPosition: cameraPos);

      await testHelper.capture(result.viewer.view, "gizmo_rotation_standalone");
    });
  });
}
