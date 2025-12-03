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

      await testHelper.capture(viewer.view, "cube_morph_animation_rest");

      var morphData = MorphAnimationData(
          Float32List.fromList(List<double>.generate(60, (i) => i / 60)),
          ["Key 1"],
          frameLengthInMs: 1000.0 / 60.0);

      await cube.setMorphAnimationData(morphData);
      FilamentApp.instance!.animationManager.update(1_000_000_000);

      await testHelper.capture(viewer.view, "cube_morph_animation_start");
      FilamentApp.instance!.animationManager.update(1_500_000_000);
      await testHelper.capture(viewer.view, "cube_morph_animation_playing");
    }, bg: kRed, cameraPosition: Vector3(3, 2, -6));
  });

  test('play/stop gltf animation', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.testDir}/assets/cube_with_morph_targets.glb");

      await viewer.addToScene(cube);

      final animationNames = await cube.getGltfAnimationNames();

      expect(animationNames.first, "Animation 1");

      await testHelper.capture(viewer.view, "gltf_animation_rest");
      await cube.playGltfAnimationByName("Animation 1");
      // need to call update manually so the animation start time is recorded as 1 second
      FilamentApp.instance!.animationManager.update(1_000_000_000);
      // this won't have moved because it's effectively the first frame
      await testHelper.capture(viewer.view, "gltf_animation_start");

      // update the animation manager by 1 second
      FilamentApp.instance!.animationManager.update(2_000_000_000);
      // cube should now be at the maximum height
      await testHelper.capture(viewer.view, "gltf_animation_1s");

      // stop the animation
      await cube.stopGltfAnimationByName("Animation 1");
      // update the animation manager by another second
      FilamentApp.instance!.animationManager.update(3_000_000_000);
      // cube should still be at maximum height
      await testHelper.capture(viewer.view, "gltf_animation_stopped");

      await viewer.destroyAsset(cube);

      await viewer.render();
    }, bg: kRed);
  });

  test('play gltf animation with faster speeds', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.testDir}/assets/cube_with_morph_targets.glb");

      await viewer.addToScene(cube);

      final animationNames = await cube.getGltfAnimationNames();

      expect(animationNames.first, "Animation 1");

      // Test double speed (2.0x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_rest");
      await cube.playGltfAnimation(0, speed: 2.0);
      // need to call update manually so the animation start time is recorded as 3 seconds
      FilamentApp.instance!.animationManager.update(1_000_000_000);
      // this won't have moved because it's effectively the first frame
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_start");

      // update the animation manager by 1 second
      FilamentApp.instance!.animationManager.update(2_000_000_000);
      // cube should be at maximum height (since speed is 2.0x, 0.5s real time = 1s animation time)
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_1s");

      // stop the animation
      await cube.stopGltfAnimation(0);

      await viewer.destroyAsset(cube);

      await viewer.render();
    }, bg: kRed);
  });

  test('play gltf animation with slower speeds', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.testDir}/assets/cube_with_morph_targets.glb");

      await viewer.addToScene(cube);

      final animationNames = await cube.getGltfAnimationNames();

      expect(animationNames.first, "Animation 1");

      // Test half speed (0.5x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_rest");
      await cube.playGltfAnimation(0, speed: 0.5);
      // need to call update manually so the animation start time is recorded as 1 second
      FilamentApp.instance!.animationManager.update(1_000_000_000);
      // this won't have moved because it's effectively the first frame
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_start");

      // update the animation manager by 1 second
      FilamentApp.instance!.animationManager.update(2_000_000_000);
      // cube should be halfway to maximum height (since speed is 0.5x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_1s");

      // stop the animation
      await cube.stopGltfAnimation(0);

      await viewer.destroyAsset(cube);

      await viewer.render();
    }, bg: kRed);
  });

  test('crossfade animations', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.testDir}/assets/cube_with_morph_targets.glb");

      await viewer.addToScene(cube);

      await cube.playGltfAnimation(0);
      FilamentApp.instance!.animationManager.update(1);
      await testHelper.capture(viewer.view, "gltf_crossfade_animation1");
      await cube.playGltfAnimation(1, crossfade: 0.25, replaceActive: true);
      FilamentApp.instance!.animationManager.update(1_000_000_000);
      
      await testHelper.capture(viewer.view, "gltf_crossfade_animation2");

      // FilamentApp.instance!.animationManager.update(2_000_000_001);
      // FilamentApp.instance!.animationManager.update(2_250_000_001);
      // await testHelper.capture(viewer.view, "gltf_crossfade_animation2");
    }, bg: kRed, cameraPosition: Vector3(0, 5, 15));
  });
}
