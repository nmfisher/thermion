@Timeout(const Duration(seconds: 600))
import 'dart:io';
import 'package:thermion_dart/thermion_dart.dart';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';
import 'package:thermion_dart/thermion_dart.dart';

void main() async {
  final testHelper = TestHelper("assets_webgpu", backend: Backend.WEBGPU);

  await testHelper.setup();

  test('load/clear skybox', () async {
    await ViewerBuilder(testHelper)
        .setRenderTargetEnabled(true)
        .execute((result) async {
      await result.viewer.loadSkybox(
          "file://${testHelper.assetsDir}/default_env_skybox.ktx");
      await testHelper.capture(result.viewer.view, "load_skybox");
      await result.viewer.removeSkybox();
      await testHelper.capture(result.viewer.view, "remove_skybox");

      await result.viewer.setPostProcessing(true);
      await result.viewer.setBloom(false, 0.01);
      await result.viewer.loadSkybox(
          "file://${testHelper.assetsDir}/default_env_skybox.ktx");
      await testHelper.capture(result.viewer.view, "load_skybox_with_postprocessing");
      await result.viewer.removeSkybox();
      await testHelper.capture(
          result.viewer.view, "remove_skybox_with_postprocessing");
    });
  });

  

  test('transform gltf to unit cube', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(0, 0, 5))
        .execute((result) async {
      var asset = await result.viewer
          .loadGltf("file://${testHelper.assetsDir}/cube.gltf");

      await result.viewer
          .loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
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
          await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
      await result.viewer
          .loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
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
          await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
      await result.viewer
          .loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
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
          await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
              await result.viewer
          .loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
      await result.viewer.showBoundingBox(asset);
      await testHelper.capture(result.viewer.view, "show_bounding_box");
      await result.viewer.hideBoundingBox(asset);
      await testHelper.capture(result.viewer.view, "hide_bounding_box");
      await result.viewer.hideBoundingBox(asset, destroy: true);
      await testHelper.capture(result.viewer.view, "destroy_bounding_box");
    });
  });
}
