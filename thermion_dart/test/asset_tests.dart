@Timeout(const Duration(seconds: 600))
import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

// Rendered frames captured by this suite are diffed against golden reference
// images by test/compare_goldens.py (run in CI, see
// .github/workflows/run-dart-tests.yml). The goldens are NOT in this repo:
// the workflow downloads a pinned golden-images artifact from a previous
// known-good run into test/golden-downloads/ (a transient dir, gitignored)
// and diffs it against test/output/. A capture must be pixel-identical to
// its golden or the comparison fails. Captures with no golden yet are
// reported as EXTRA and do not fail the comparison.

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

      // The rendered frame is verified against the golden reference image by
      // compare_goldens.py (goldens come from a pinned CI artifact, not this
      // repo — see the comment at the top of this file).
      await testHelper.capture(result.viewer.view, "flight_helmet");
    });
  });

  test('transform FlightHelmet to unit cube', () async {
    await ViewerBuilder(testHelper).setCameraLookAt(Vector3(0, 0, 5)).execute((result) async {
      var asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf");

      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");

      await testHelper.capture(result.viewer.view, "flight_helmet_before_unit_cube");

      // Note: getBoundingBox reports model-space bounds, which do not change
      // when the root transform is updated.
      final boundsBefore = await asset.getBoundingBox();
      final sizeBefore = boundsBefore.max - boundsBefore.min;
      final maxDimBefore = max(max(sizeBefore.x, sizeBefore.y), sizeBefore.z);
      // The asset loaded with real, finite geometry well under a unit across.
      expect(maxDimBefore, greaterThan(0.0));
      expect(maxDimBefore.isFinite, true);
      expect(maxDimBefore, lessThan(1.0));

      await asset.transformToUnitCube();

      // transformToUnitCube rescales the root entity so the largest dimension
      // spans the unit cube centered on the origin (half-extent 1.0).
      final translation = Vector3.zero();
      final rotation = Quaternion.identity();
      final scale = Vector3.zero();
      (await asset.getWorldTransform()).decompose(translation, rotation, scale);
      final expectedScale = 2.0 / maxDimBefore;
      expect(scale.x, closeTo(expectedScale, 0.01));
      expect(scale.y, closeTo(expectedScale, 0.01));
      expect(scale.z, closeTo(expectedScale, 0.01));

      // The rendered frames are verified against the golden reference images
      // by compare_goldens.py (goldens come from a pinned CI artifact, not
      // this repo — see the comment at the top of this file).
      await testHelper.capture(result.viewer.view, "flight_helmet_after_unit_cube");
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
