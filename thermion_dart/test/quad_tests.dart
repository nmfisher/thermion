import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");
  await testHelper.setup();

  group("image", () {
    test('set 2D texture from decoded image', () async {
      await testHelper.withViewer((viewer) async {
        final quad = await FilamentApp.instance!.createTexturedQuad();
        await quad.setBackgroundColor(1, 0, 0, 1.0);
        await viewer.addToScene(quad);
      }, bg: kBlue);
    });
  });
}
