import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("assets");
  await testHelper.setup();
  group("background", () {
    test('set background color', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setBackgroundColor(0, 1, 0, 1);
        await testHelper.capture(viewer.view, "background_green");
        await viewer.setBackgroundColor(1, 0, 0, 1);
        await testHelper.capture(viewer.view, "background_red");
      });
    });

    test('set background image', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setBackgroundImage("file://${testHelper.testDir}/assets/cube_texture2_512x512.png");
        await testHelper.capture(viewer.view, "background_image");
      });
    });
  });
}
