import 'package:thermion_dart/src/filament/src/interface/light_options.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("lights");
  await testHelper.setup();
  group("lights", () {
    test('add/clear point light', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");

        var light = await viewer.addDirectLight(
            DirectLight.point(intensity: 1000000, falloffRadius: 10));
        await viewer.setLightPosition(light, 1, 2, 2);
        await testHelper.capture(viewer.view, "add_point_light");
        await viewer.setLightPosition(light, -1, 2, 2);
        await testHelper.capture(viewer.view, "move_point_light");
        await viewer.removeLight(light);
        await testHelper.capture(viewer.view, "remove_point_light");
      });
    });


  });
}
