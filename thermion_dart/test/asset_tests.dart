@Timeout(const Duration(seconds: 600))
import 'dart:io';

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("assets");
  await testHelper.setup();

  test('load/clear skybox', () async {
    await ViewerBuilder(testHelper)
        .setRenderTargetEnabled(true)
        .execute((result) async {
      await result.viewer.loadSkybox(
          "file://${testHelper.testDir}/assets/default_env_skybox.ktx");
      await testHelper.capture(result.viewer.view, "load_skybox");
      await result.viewer.removeSkybox();
      await testHelper.capture(result.viewer.view, "remove_skybox");

      await result.viewer.setPostProcessing(true);
      await result.viewer.setBloom(false, 0.01);
      await result.viewer.loadSkybox(
          "file://${testHelper.testDir}/assets/default_env_skybox.ktx");
      await testHelper.capture(result.viewer.view, "load_skybox_with_postprocessing");
      await result.viewer.removeSkybox();
      await testHelper.capture(
          result.viewer.view, "remove_skybox_with_postprocessing");
    });
  });

  test('sync load/remove gltf from uri', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 0, 5))
        .execute((result) async {
      var asset = await result.viewer
          .loadGltf("file://${testHelper.testDir}/assets/cube.gltf");
      await result.viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await testHelper.capture(result.viewer.view, "gltf_loaded");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(result.viewer.view, "gltf_removed");
    });
  });

  test('async load/remove gltf from uri', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 0, 5))
        .execute((result) async {
      var asset = await result.viewer.loadGltf(
          "file://${testHelper.testDir}/assets/cube.gltf",
          loadAsync: true);
      await result.viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await testHelper.capture(result.viewer.view, "gltf_async_loaded");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(result.viewer.view, "gltf_async_removed");
    });
  });

  test('sync load/remove gltf from buffer', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 0, 5))
        .execute((result) async {
      var assetData =
          File("${testHelper.testDir}/assets/cube.gltf").readAsBytesSync();
      var asset = await result.viewer.loadGltfFromBuffer(assetData,
          resourceUri: "${testHelper.testDir}/assets",
          loadResourcesAsync: false);
      await result.viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await testHelper.capture(result.viewer.view, "gltf_load_from_buffer");
    });
  });

  test('transform gltf to unit cube', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 0, 5))
        .execute((result) async {
      var asset = await result.viewer
          .loadGltf("file://${testHelper.testDir}/assets/cube.gltf");

      await result.viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await asset.setTransform(Matrix4.compose(
          Vector3.zero(), Quaternion.identity(), Vector3.all(2)));
      await testHelper.capture(result.viewer.view, "gltf_before_unit_cube");
      await asset.transformToUnitCube();
      await testHelper.capture(result.viewer.view, "gltf_after_unit_cube");
    });
  });

  test('add/remove asset from scene ', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 0, 5))
        .execute((result) async {
      var asset =
          await result.viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");
      await result.viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await testHelper.capture(result.viewer.view, "asset_added");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(result.viewer.view, "asset_removed");
    });
  });

  test('destroy assets', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 0, 5))
        .execute((result) async {
      var asset =
          await result.viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");
      await result.viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await testHelper.capture(result.viewer.view, "assets_present");
      await result.viewer.destroyAssets();
      await testHelper.capture(result.viewer.view, "assets_destroyed");
    });
  });

  test('add/remove bounding box', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 0, 5))
        .execute((result) async {
      var asset =
          await result.viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");
              await result.viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await result.viewer.showBoundingBox(asset);
      await testHelper.capture(result.viewer.view, "show_bounding_box");
      await result.viewer.hideBoundingBox(asset);
      await testHelper.capture(result.viewer.view, "hide_bounding_box");
      await result.viewer.hideBoundingBox(asset, destroy: true);
      await testHelper.capture(result.viewer.view, "destroy_bounding_box");
    });
  });
}
