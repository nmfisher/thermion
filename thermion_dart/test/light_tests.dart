import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("lights");
  group("lights", () {
    test('add/clear point lights', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.loadGlb("file://${testHelper.testDir}/assets/cube.glb");

        var light = await viewer.addDirectLight(
            DirectLight.point(intensity: 10000000000, falloffRadius: 10));
        await viewer.setLightPosition(light, 0, 10, 0);
        await testHelper.capture(viewer, "add_point_light");
        await viewer.destroyLights();
        await testHelper.capture(viewer, "remove_lights");
      });
    });

    test('add/remove IBL', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.loadGlb("file://${testHelper.testDir}/assets/cube.glb");

        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await testHelper.capture(viewer, "load_ibl");
        await viewer.removeIbl();
        await testHelper.capture(viewer, "remove_ibl");
      });
    });

    test('add/remove skybox', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.loadGlb("file://${testHelper.testDir}/assets/cube.glb");

        await viewer
            .loadSkybox("file://${testHelper.testDir}/assets/default_env_skybox.ktx");
        await testHelper.capture(viewer, "load_skybox");
        await viewer.removeSkybox();
        await testHelper.capture(viewer, "remove_skybox");
      });
    });
  });
}
