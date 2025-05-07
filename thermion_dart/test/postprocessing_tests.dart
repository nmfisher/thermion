@Timeout(const Duration(seconds: 600))
import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/interface/light_options.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("postprocessing");
  await testHelper.setup();
  group("assets", () {
    test('enable/disable postprocessing', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
        await testHelper.capture(viewer.view, "empty_scene_no_postprocessing");
        await viewer.setPostProcessing(true);
        await testHelper.capture(viewer.view, "empty_scene_postprocessing");
      }, postProcessing: false, createRenderTarget: true);
    });

    test('bloom', () async {
      await testHelper.withViewer((viewer) async {
        await FilamentApp.instance!.setClearOptions(1, 1, 1, 1, clear: false);
        var asset = await viewer
            .loadGltf("file://${testHelper.testDir}/assets/cube.glb");
        var light = await viewer.addDirectLight(
            DirectLight.point(intensity: 1000000, falloffRadius: 10));
        await viewer.setLightPosition(light, 1, 2, 2);
        await viewer.setBloom(false, 0.5);
        await testHelper.capture(viewer.view, "postprocessing_no_bloom");
        await viewer.setBloom(true, 0.5);
        await testHelper.capture(viewer.view, "postprocessing_bloom_0.5");
        await viewer.setBloom(true, 1.0);
        await testHelper.capture(viewer.view, "postprocessing_bloom_1.0");
      }, postProcessing: true, createRenderTarget: true, bg: kBlue);
    });

    
  });
}
