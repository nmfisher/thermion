@Timeout(const Duration(seconds: 600))
import 'dart:math';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

// WebGPU (Dawn) variant of asset_tests.dart. Rendered captures are the
// regression guard for the WebGPU readback path: an all-zero buffer means
// readPixels broke again (see Engine_flushAndWait's Dawn event pumping and
// the FLOAT→UBYTE blitter workaround in FFIFilamentApp.capture).
void main() async {
  final testHelper = TestHelper("assets_webgpu", backend: Backend.WEBGPU);

  await testHelper.setup();

  test('load/clear skybox', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      await result.viewer.loadSkybox("file://${testHelper.assetsDir}/default_env_skybox.ktx");
      var capture = await testHelper.capture(result.viewer.view, "load_skybox");
      expect(_nonZeroPixels(capture), greaterThan(0), reason: "skybox pixels must survive the WebGPU readback");
      await result.viewer.removeSkybox();
      capture = await testHelper.capture(result.viewer.view, "remove_skybox");

      await result.viewer.setPostProcessing(true);
      await result.viewer.setBloom(false, 0.01);
      await result.viewer.loadSkybox("file://${testHelper.assetsDir}/default_env_skybox.ktx");
      capture = await testHelper.capture(result.viewer.view, "load_skybox_with_postprocessing");
      expect(_nonZeroPixels(capture), greaterThan(0), reason: "skybox pixels must survive the WebGPU readback");
      await result.viewer.removeSkybox();
      await testHelper.capture(result.viewer.view, "remove_skybox_with_postprocessing");
    });
  });

  test('transform gltf to unit cube', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.gltf");

      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
      await asset.setTransform(Matrix4.compose(Vector3.zero(), Quaternion.identity(), Vector3.all(2)));
      await testHelper.capture(result.viewer.view, "gltf_before_unit_cube");

      // getBoundingBox reports model-space bounds (unchanged by the root
      // transform): finite and positive regardless of the base size.
      final bounds = await asset.getBoundingBox();
      final size = bounds.max - bounds.min;
      final maxDim = max(max(size.x, size.y), size.z);
      expect(maxDim, greaterThan(0.0));
      expect(maxDim.isFinite, true);

      await asset.transformToUnitCube();
      await testHelper.capture(result.viewer.view, "gltf_after_unit_cube");

      // transformToUnitCube rescales the root so the largest dimension
      // spans the unit cube centered on the origin (half-extent 1.0).
      final translation = Vector3.zero();
      final rotation = Quaternion.identity();
      final scale = Vector3.zero();
      (await asset.getWorldTransform()).decompose(translation, rotation, scale);
      final expectedScale = 2.0 / maxDim;
      expect(scale.x, closeTo(expectedScale, 0.01));
      expect(scale.y, closeTo(expectedScale, 0.01));
      expect(scale.z, closeTo(expectedScale, 0.01));
    });
  });

  test('add/remove asset from scene ', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).setBackgroundColor(kRed).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
      var capture = await testHelper.capture(result.viewer.view, "asset_added");
      expect(
        _nonZeroPixels(capture),
        greaterThan(0),
        reason: "red background + cube must produce non-zero pixels on WebGPU",
      );
      await result.viewer.removeFromScene(asset);
      capture = await testHelper.capture(result.viewer.view, "asset_removed");
      expect(_nonZeroPixels(capture), greaterThan(0), reason: "red background must produce non-zero pixels on WebGPU");
    });
  });

  test('destroy assets', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).setBackgroundColor(kRed).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");

      final bounds = await asset.getBoundingBox();
      final size = bounds.max - bounds.min;
      expect(max(max(size.x, size.y), size.z), greaterThan(0.0));

      var capture = await testHelper.capture(result.viewer.view, "assets_present");
      expect(_nonZeroPixels(capture), greaterThan(0));
      await result.viewer.destroyAssets();
      capture = await testHelper.capture(result.viewer.view, "assets_destroyed");
      expect(_nonZeroPixels(capture), greaterThan(0), reason: "red background must produce non-zero pixels on WebGPU");
    });
  });

  test('add/remove bounding box', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).setBackgroundColor(kRed).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");

      final bounds = await asset.getBoundingBox();
      final size = bounds.max - bounds.min;
      expect(max(max(size.x, size.y), size.z), greaterThan(0.0));
      expect(size.x.isFinite && size.y.isFinite && size.z.isFinite, true);

      await result.viewer.showBoundingBox(asset);
      var capture = await testHelper.capture(result.viewer.view, "show_bounding_box");
      expect(_nonZeroPixels(capture), greaterThan(0));
      await result.viewer.hideBoundingBox(asset);
      capture = await testHelper.capture(result.viewer.view, "hide_bounding_box");
      expect(_nonZeroPixels(capture), greaterThan(0));
      await result.viewer.hideBoundingBox(asset, destroy: true);
      capture = await testHelper.capture(result.viewer.view, "destroy_bounding_box");
      expect(_nonZeroPixels(capture), greaterThan(0));
    });
  });
}

/// Counts non-black pixels (RGBA, 4 bytes per pixel) across all views of a
/// capture — the readback regression check shared by every test above.
int _nonZeroPixels(Map<View, Uint8List> capture) {
  var nonZero = 0;
  for (final pixels in capture.values) {
    for (var i = 0; i + 3 < pixels.length; i += 4) {
      if (pixels[i] != 0 || pixels[i + 1] != 0 || pixels[i + 2] != 0) {
        nonZero++;
      }
    }
  }
  return nonZero;
}
