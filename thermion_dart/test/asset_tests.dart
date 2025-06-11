@Timeout(const Duration(seconds: 600))
import 'dart:io';

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("assets");
  await testHelper.setup();

    test('load/clear skybox', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.loadSkybox(
            "file://${testHelper.testDir}/assets/default_env_skybox.ktx");
        await testHelper.capture(viewer.view, "load_skybox");
        await viewer.removeSkybox();
        await testHelper.capture(viewer.view, "remove_skybox");

        await viewer.setPostProcessing(true);
        await viewer.setBloom(false, 0.01);
        await viewer.loadSkybox(
            "file://${testHelper.testDir}/assets/default_env_skybox.ktx");
        await testHelper.capture(
            viewer.view, "load_skybox_with_postprocessing");
        await viewer.removeSkybox();
        await testHelper.capture(
            viewer.view, "remove_skybox_with_postprocessing");
      }, createRenderTarget: true);
    });

    test('sync load/remove gltf from uri', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer.loadGltf(
            "file://${testHelper.testDir}/assets/cube.gltf");
        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await testHelper.capture(viewer.view, "gltf_loaded");
        await viewer.removeFromScene(asset);
        await testHelper.capture(viewer.view, "gltf_removed");
      }, cameraPosition: Vector3(0, 0, 5));
    });

    test('async load/remove gltf from uri', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer.loadGltf("file://${testHelper.testDir}/assets/cube.gltf", loadAsync: true);
        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await testHelper.capture(viewer.view, "gltf_async_loaded");
        await viewer.removeFromScene(asset);
        await testHelper.capture(viewer.view, "gltf_async_removed");
      }, cameraPosition: Vector3(0, 0, 5));
    });

    test('sync load/remove gltf from buffer', () async {
      await testHelper.withViewer((viewer) async {
        var assetData =
            File("${testHelper.testDir}/assets/cube.gltf").readAsBytesSync();
        var asset = await viewer.loadGltfFromBuffer(assetData,
            resourceUri: "${testHelper.testDir}/assets", loadResourcesAsync: false);
        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await testHelper.capture(viewer.view, "gltf_load_from_buffer");
      }, cameraPosition: Vector3(0, 0, 5));
    });

    test('transform gltf to unit cube', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer.loadGltf(
            "file://${testHelper.testDir}/assets/cube.gltf");

        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await asset.setTransform(Matrix4.compose(
            Vector3.zero(), Quaternion.identity(), Vector3.all(2)));
        await testHelper.capture(viewer.view, "gltf_before_unit_cube");
        await asset.transformToUnitCube();
        await testHelper.capture(viewer.view, "gltf_after_unit_cube");
      }, cameraPosition: Vector3(0, 0, 5));
    });

    test('add/remove asset from scene ', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer
            .loadGltf("file://${testHelper.testDir}/assets/cube.glb");
        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await testHelper.capture(viewer.view, "asset_added");
        await viewer.removeFromScene(asset);
        await testHelper.capture(viewer.view, "asset_removed");
      }, cameraPosition: Vector3(0, 0, 5));
    });

    test('destroy assets', () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer
            .loadGltf("file://${testHelper.testDir}/assets/cube.glb");
        await viewer
            .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
        await testHelper.capture(viewer.view, "assets_present");
        await viewer.destroyAssets();
        await testHelper.capture(viewer.view, "assets_destroyed");
      }, cameraPosition: Vector3(0, 0, 5));
    });

}
