import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("overlay");
  await testHelper.setup();

  test('toggle grid visibility', () async {
    await testHelper.withViewer(
      (viewer) async {
        await viewer.setGridOverlayVisibility(true);
        await testHelper.capture(viewer.view, "grid_visible");
        await testHelper.capture(viewer.view, "grid_visible");
        await viewer.setGridOverlayVisibility(false);
        await testHelper.capture(viewer.view, "grid_hidden");          
        await testHelper.capture(viewer.view, "grid_hidden");          
      },
      postProcessing: true,
    );
  });

}
