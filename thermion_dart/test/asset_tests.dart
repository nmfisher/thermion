import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("lights");
  group("assets", () {
    test('add/clear asset', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer.loadGlb("file://${testHelper.testDir}/assets/cube.glb");
        await testHelper.capture(viewer, "asset_loaded");
        await viewer.destroyAssets();
        await testHelper.capture(viewer, "assets_cleared");
      }, bg: kRed);
    });
  });
}
