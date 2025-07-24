import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("overlay");
  await testHelper.setup();

  test('toggle grid visibility', () async {
    await testHelper.withViewer(
      (viewer) async {
        await viewer.setGridOverlayVisibility(true);
        await testHelper.capture(viewer.view, "grid_visible");
        final camera = await viewer.getActiveCamera();
        await camera.lookAt(Vector3(0, 5, 10));
        await testHelper.capture(viewer.view, "grid_visible_angle");
        await viewer.setGridOverlayVisibility(false);
        await testHelper.capture(viewer.view, "grid_hidden");
      },
      postProcessing: true,
    );
  });
}
