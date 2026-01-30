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
        for (int i = 0; i < 10; i++) {
          await camera.lookAt(Vector3(0, 1 + (i* 10), 0.005),
              focus: Vector3.zero());
          await testHelper.capture(viewer.view, "grid_visible_fade${i}");
        }
        await viewer.setGridOverlayVisibility(false);
        await testHelper.capture(viewer.view, "grid_hidden");
      },
      postProcessing: true,
    );
  });

  test('grid with custom spacing', () async {
    await testHelper.withViewer(
      (viewer) async {
        // Test with tighter spacing
        await viewer.setGridOverlayVisibility(true,
            spacing: [0.5, 2.0, 10.0]);
        await testHelper.capture(viewer.view, "grid_custom_spacing");
        final camera = await viewer.getActiveCamera();
        await camera.lookAt(Vector3(0, 5, 10));
        await testHelper.capture(viewer.view, "grid_custom_spacing_angle");
      },
      postProcessing: true,
    );
  });

  test('grid with custom fade parameters', () async {
    await testHelper.withViewer(
      (viewer) async {
        // Test with adjusted fade ranges for a smaller scene
        await viewer.setGridOverlayVisibility(true,
            spacing: [0.5, 2.0, 10.0],
            fadeInStart: [0.001, 1.0, 5.0],
            fadeInEnd: [0.001, 10.0, 50.0],
            fadeOutStart: [2.0, 50.0, 500.0],
            fadeOutEnd: [20.0, 200.0, 2000.0]);
        await testHelper.capture(viewer.view, "grid_custom_fade");
        final camera = await viewer.getActiveCamera();
        await camera.lookAt(Vector3(0, 5, 10));
        await testHelper.capture(viewer.view, "grid_custom_fade_angle");

        // Test fade behavior by moving camera away
        await camera.lookAt(Vector3(0, 100, 0.005), focus: Vector3.zero());
        await testHelper.capture(viewer.view, "grid_custom_fade_distant");
      },
      postProcessing: true,
    );
  });
}
