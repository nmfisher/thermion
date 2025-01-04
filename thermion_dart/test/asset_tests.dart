import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("lights");
  group("assets", () {
    test('add/clear asset', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer.loadGlb("file://${testHelper.testDir}/assets/cube.glb");
        await testHelper.capture(viewer, "asset_loaded");
        await viewer.destroyAssets();
        await viewer.destroyLights();
        await viewer.removeSkybox();
        await viewer.removeIbl();
        await testHelper.capture(viewer, "assets_cleared");
        asset = await viewer.loadGlb("file://${testHelper.testDir}/assets/cube.glb");
        await testHelper.capture(viewer, "asset_reloaded");
      }, bg: kRed);
    });
  });
}
