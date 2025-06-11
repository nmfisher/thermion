import 'package:thermion_dart/src/filament/src/interface/light_options.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("lights");
  await testHelper.setup();
  
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


      test('load/remove ibl', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer
            .loadGltf("file://${testHelper.testDir}/assets/cube.glb");
        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await testHelper.capture(viewer.view, "ibl_loaded");
        await viewer.removeIbl();
        await testHelper.capture(viewer.view, "ibl_removed");
      }, cameraPosition: Vector3(0, 0, 5));
    });
}
