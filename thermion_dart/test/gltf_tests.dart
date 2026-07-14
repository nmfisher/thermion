import 'dart:io';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gltf");

  await testHelper.setup();

  test('sync load/remove glb', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      var asset = await result.viewer
          .loadGltf("file://${testHelper.assetsDir}/cube.glb");

      await testHelper.capture(result.viewer.view, "glb_loaded");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(result.viewer.view, "glb_removed");
    });
  });

  test('sync load/remove gltf from uri', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      var asset = await result.viewer
          .loadGltf("file://${testHelper.assetsDir}/cube.gltf");

      await testHelper.capture(result.viewer.view, "gltf_loaded");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(result.viewer.view, "gltf_removed");
    });
  });

  test('async load/remove gltf from uri', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      var asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.gltf",
          loadAsync: true);
      await testHelper.capture(result.viewer.view, "gltf_async_loaded");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(result.viewer.view, "gltf_async_removed");
    });
  });

  test('sync load/remove gltf from buffer', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      var assetData =
          File("${testHelper.assetsDir}/cube.gltf").readAsBytesSync();
      var asset = await result.viewer.loadGltfFromBuffer(assetData,
          resourceUri: "${testHelper.assetsDir}", loadResourcesAsync: false);
      await testHelper.capture(result.viewer.view, "gltf_load_from_buffer");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(
          result.viewer.view, "gltf_load_from_buffer_removed");
    });
  });
}
