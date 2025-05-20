import 'dart:async';
import 'dart:typed_data';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("animation");
  await testHelper.setup();

  test('get morph target names', () async {
    await testHelper.withViewer((viewer) async {
      var cube = await viewer.loadGltf("${testHelper.testDir}/assets/cube.glb");
      var morphTargets = await cube.getMorphTargetNames();
      expect(morphTargets.length, 0);

      var childEntities = await cube.getChildEntities();
      var childEntity = childEntities.first;

      morphTargets = await cube.getMorphTargetNames(entity: childEntity);
      expect(morphTargets.length, 0);

      cube = await viewer
          .loadGltf("${testHelper.testDir}/assets/cube_with_morph_targets.glb");
      morphTargets = await cube.getMorphTargetNames();
      expect(morphTargets.length, 0);

      childEntities = await cube.getChildEntities();

      morphTargets =
          await cube.getMorphTargetNames(entity: childEntities.first);
      expect(morphTargets.length, 1);
      expect(morphTargets.first, "Key 1");
    });
  });

  test('set morph target weights', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.testDir}/assets/cube_with_morph_targets.glb");

      await viewer.addToScene(cube);

      await testHelper.capture(viewer.view, "cube_no_morph");

      await cube
          .setMorphTargetWeights((await cube.getChildEntities()).first, [1.0]);
      await testHelper.capture(viewer.view, "cube_with_morph");
    }, bg: kRed, cameraPosition: Vector3(3, 2, 6));
  });

  test('set morph target animation', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.testDir}/assets/cube_with_morph_targets.glb");

      await viewer.addToScene(cube);

      await testHelper.capture(viewer.view, "cube_morph_animation_reset");

      var morphData = MorphAnimationData(Float32List.fromList([1.0]), ["Key 1"],
          frameLengthInMs: 1000.0 / 60.0);

      await cube.setMorphAnimationData(morphData);
      await viewer.render();
      await testHelper.capture(viewer.view, "cube_morph_animation_playing");
    }, bg: kRed, cameraPosition: Vector3(3, 2, -6));
  });

  test('play/stop gltf animation', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.testDir}/assets/cube_with_morph_targets.glb");

      await viewer.addToScene(cube);

      final animationNames = await cube.getGltfAnimationNames();

      expect(animationNames.first, "CubeAction");

      await testHelper.capture(viewer.view, "gltf_animation_rest");

      await viewer.render();

      await cube.playGltfAnimation(0);
      
      await Future.delayed(Duration(milliseconds: 750));
      await viewer.render();
      await testHelper.capture(viewer.view, "gltf_animation_started");
      await viewer.render();
      await Future.delayed(Duration(milliseconds: 1000));
      await viewer.render();
      await cube.stopGltfAnimation(0);
      await viewer.render();
      await testHelper.capture(viewer.view, "gltf_animation_stopped");

      await viewer.destroyAsset(cube);

      await viewer.render();

      await testHelper.capture(viewer.view, "gltf_asset_destroyed");
    }, bg: kRed);
  });
}
