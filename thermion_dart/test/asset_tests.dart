@Timeout(const Duration(seconds: 600))
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("assets");
  await testHelper.setup();
  group("assets", () {
    // test('load/clear skybox', () async {
    //   await testHelper.withViewer((viewer) async {
    //     final camera = await viewer.getActiveCamera();
    //     print(await camera.getModelMatrix());
    //     print(await camera.getViewMatrix());
    //     print(await camera.getProjectionMatrix());
    //     await camera.lookAt(Vector3(0, 0, 10),
    //         focus: Vector3.zero(), up: Vector3(0, 1, 0));
    //     await viewer.loadSkybox(
    //         "file://${testHelper.testDir}/assets/default_env_skybox.ktx");
    //     await testHelper.capture(viewer.view, "load_skybox");
    //     await viewer.removeSkybox();
    //     await testHelper.capture(viewer.view, "remove_skybox");
    //   });
    // });

    test('load/remove ibl', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer
            .loadGlb("file://${testHelper.testDir}/assets/cube.glb");
        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await testHelper.capture(viewer.view, "ibl_loaded");
        await viewer.removeIbl();
        await testHelper.capture(viewer.view, "ibl_removed");
      }, cameraPosition: Vector3(0, 0, 5));
    });

    // test('add/remove asset from scene ', () async {
    //   await testHelper.withViewer((viewer) async {
    //     var asset = await viewer
    //         .loadGlb("file://${testHelper.testDir}/assets/cube.glb");
    //     await viewer
    //         .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
    //     await testHelper.capture(viewer.view, "asset_added");
    //     await viewer.removeFromScene(asset);
    //     await testHelper.capture(viewer.view, "asset_removed");
    //   }, cameraPosition: Vector3(0, 0, 5));
    // });

    // test('destroy assets', () async {
    //   await testHelper.withViewer((viewer) async {
    //     var asset = await viewer
    //         .loadGlb("file://${testHelper.testDir}/assets/cube.glb");
    //     await viewer
    //         .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
    //     await testHelper.capture(viewer.view, "assets_present");
    //     await viewer.destroyAssets();
    //     await testHelper.capture(viewer.view, "assets_destroyed");
    //   }, cameraPosition: Vector3(0, 0, 5));
    // });


    
      
        // await viewer.destroyLights();
        // await viewer.removeSkybox();
        // await viewer.removeIbl();
        
        // asset = await viewer
        //     .loadGlb("file://${testHelper.testDir}/assets/cube.glb");
        // await testHelper.capture(viewer.view, "asset_reloaded");
  });
}
