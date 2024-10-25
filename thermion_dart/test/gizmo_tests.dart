// ignore_for_file: unused_local_variable

import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gizmo");

  group('gizmo', () {
    test('add gizmo to scene', () async {
      var viewer = await testHelper.createViewer();
      var view = await viewer.getViewAt(0);
      var gizmo = await viewer.createGizmo(view);
      await testHelper.capture(viewer, "gizmo_add_to_scene");
      await viewer.dispose();
    });
  });
}
