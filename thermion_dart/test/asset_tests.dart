@Timeout(const Duration(seconds: 600))
import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

/// Counts the pixels in a captured FLOAT RGBA pixel buffer whose luminance
/// exceeds [threshold].
int countLitPixels(Float32List pixels, {double threshold = 0.01}) {
  var lit = 0;
  for (var i = 0; i + 2 < pixels.length; i += 4) {
    final luminance = 0.2126 * pixels[i] + 0.7152 * pixels[i + 1] + 0.0722 * pixels[i + 2];
    if (luminance > threshold) {
      lit++;
    }
  }
  return lit;
}

void main() async {
  final testHelper = TestHelper("assets");

  await testHelper.setup();

  test('load/clear skybox', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      await result.viewer.loadSkybox("file://${testHelper.assetsDir}/default_env_skybox.ktx");
      await testHelper.capture(result.viewer.view, "load_skybox");
      await result.viewer.removeSkybox();
      await testHelper.capture(result.viewer.view, "remove_skybox");

      await result.viewer.setPostProcessing(true);
      await result.viewer.setBloom(false, 0.01);
      await result.viewer.loadSkybox("file://${testHelper.assetsDir}/default_env_skybox.ktx");
      await testHelper.capture(result.viewer.view, "load_skybox_with_postprocessing");
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
      await asset.transformToUnitCube();
      await testHelper.capture(result.viewer.view, "gltf_after_unit_cube");
    });
  });

  test('load and render FlightHelmet', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0.5, 0.4, 1.0)).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf");

      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");

      // The Khronos FlightHelmet is a multi-mesh PBR asset: a single
      // "FlightHelmet" root node with one child node (and thus one renderable
      // entity) per mesh part.
      final childNames = await asset.getChildEntityNames();
      expect(
        childNames,
        unorderedEquals([
          "FlightHelmet",
          "GlassPlastic_low",
          "LeatherParts_low",
          "Lenses_low",
          "MetalParts_low",
          "RubberWood_low",
        ]),
      );

      // Each mesh part is a single primitive with its own material instance
      // (base color + normal + occlusion/roughness/metallic textures).
      final materialInstances = await asset.getMaterialInstancesAsMap();
      expect(materialInstances.length, 5);
      for (final primitives in materialInstances.values) {
        expect(primitives.length, 1);
      }

      final frames = await testHelper.capture(result.viewer.view, "flight_helmet");
      final pixels = frames.values.single.buffer.asFloat32List();
      // With no skybox the background is black, so any lit pixels must come
      // from the rendered helmet.
      final litPixels = countLitPixels(pixels);
      expect(pixels.length, greaterThan(0));
      expect(litPixels, greaterThan(512 * 512 ~/ 100));
    });
  });

  test('transform FlightHelmet to unit cube', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf");

      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");

      // Note: getBoundingBox reports model-space bounds, which do not change
      // when the root transform is updated.
      final boundsBefore = await asset.getBoundingBox();
      final sizeBefore = boundsBefore.max - boundsBefore.min;
      final maxDimBefore = max(max(sizeBefore.x, sizeBefore.y), sizeBefore.z);
      final centerBefore = (boundsBefore.min + boundsBefore.max) / 2.0;
      // The raw helmet geometry is well under a unit across.
      expect(maxDimBefore, lessThan(1.0));

      final framesBefore = await testHelper.capture(result.viewer.view, "flight_helmet_before_unit_cube");
      final litBefore = countLitPixels(framesBefore.values.single.buffer.asFloat32List());
      expect(litBefore, greaterThan(0));

      await asset.transformToUnitCube();
      final framesAfter = await testHelper.capture(result.viewer.view, "flight_helmet_after_unit_cube");
      final litAfter = countLitPixels(framesAfter.values.single.buffer.asFloat32List());

      // transformToUnitCube rescales the root entity so the largest dimension
      // spans the unit cube centered on the origin (half-extent 1.0), and
      // recenters the model on the origin.
      final translation = Vector3.zero();
      final rotation = Quaternion.identity();
      final scale = Vector3.zero();
      (await asset.getWorldTransform()).decompose(translation, rotation, scale);
      final expectedScale = 2.0 / maxDimBefore;
      expect(scale.x, closeTo(expectedScale, 0.01));
      expect(scale.y, closeTo(expectedScale, 0.01));
      expect(scale.z, closeTo(expectedScale, 0.01));
      expect(translation.x, closeTo(-expectedScale * centerBefore.x, 0.01));
      expect(translation.y, closeTo(-expectedScale * centerBefore.y, 0.01));
      expect(translation.z, closeTo(-expectedScale * centerBefore.z, 0.01));

      // The rescaled helmet occupies more of the frame than the raw one.
      expect(litAfter, greaterThan(litBefore));
    });
  });

  test('add/remove asset from scene ', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
      await testHelper.capture(result.viewer.view, "asset_added");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(result.viewer.view, "asset_removed");
    });
  });

  test('destroy assets', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
      await testHelper.capture(result.viewer.view, "assets_present");
      await result.viewer.destroyAssets();
      await testHelper.capture(result.viewer.view, "assets_destroyed");
    });
  });

  test('add/remove bounding box', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb");
      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
      await result.viewer.showBoundingBox(asset);
      await testHelper.capture(result.viewer.view, "show_bounding_box");
      await result.viewer.hideBoundingBox(asset);
      await testHelper.capture(result.viewer.view, "hide_bounding_box");
      await result.viewer.hideBoundingBox(asset, destroy: true);
      await testHelper.capture(result.viewer.view, "destroy_bounding_box");
    });
  });
}
