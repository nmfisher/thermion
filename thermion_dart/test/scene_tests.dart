import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("scene");
  await testHelper.setup();

  test('show stencil highlight', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.view.setStencilBufferEnabled(true);
      final cube = await viewer.createGeometry(
          GeometryHelper.cube(
            normals: true,
            uvs: true,
          ),
          keepData: true,
          materialInstances: []);

      await viewer.addToScene(cube);

      final scene = await viewer.view.getScene();
      await scene.setStencilHighlight(cube);

      await testHelper.capture(viewer.view, "stencil_highlight");
      await scene.removeStencilHighlight(cube);
      await testHelper.capture(viewer.view, "stencil_highlight_removed");
    }, createStencilBuffer: true);
  });
}
