import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gltf_animation");
  await testHelper.setup();

  test(
    'getGltfAnimationNames returns the names of all animations in a gltf asset',
    () async {
      await ViewerBuilder(testHelper).execute((result) async {
        final viewer = result.viewer;
        final cube = await viewer.loadGltf(
          "${testHelper.assetsDir}/cube_with_morph_targets.glb",
        );
        final animationNames = await cube.getGltfAnimationNames();
        expect(animationNames.length, 2);
        expect(animationNames.first, "Animation 1");
      });
    },
  );

  test('play/stop gltf animation', () async {
    await ViewerBuilder(
      testHelper,
      bg: kRed,
    ).setCameraLookAt(Vector3(3, 4, 15), focus: Vector3.zero()).execute((
      result,
    ) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf(
        "${testHelper.assetsDir}/cube_with_morph_targets.glb",
        addToScene: true,
      );

      await testHelper.capture(viewer.view, "play_gltf_animation_0");
      final duration = await cube.getGltfAnimationDuration(0);
      final durationNanos = (duration * 1_000_000_000).toInt();

      final halfDurationNanos = durationNanos ~/ 2;
      await cube.playGltfAnimation(0);

      // call update manually so the animation start time is recorded as
      // 1 nanosecond. This won't have moved because it's effectively the
      // first frame
      await FilamentApp.instance!.animationManager.update(1);
      await testHelper.capture(viewer.view, "play_gltf_animation_1");

      // update the animation manager
      await FilamentApp.instance!.animationManager.update(halfDurationNanos);
      await testHelper.capture(viewer.view, "play_gltf_animation_2");

      await FilamentApp.instance!.animationManager.update(durationNanos);
      await testHelper.capture(viewer.view, "play_gltf_animation_3");

      // stop the animation
      await cube.stopGltfAnimationByName("Animation 1");
      // update the animation manager by another second
      await FilamentApp.instance!.animationManager.update(durationNanos + 1);
      // cube should still be at maximum height
      await testHelper.capture(viewer.view, "stop_gltf_animation");
    });
  });

  test('play gltf animation with faster speeds', () async {
    await ViewerBuilder(testHelper, bg: kRed).execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf(
        "${testHelper.assetsDir}/cube_with_morph_targets.glb",
        addToScene: true,
      );

      final animationNames = await cube.getGltfAnimationNames();

      expect(animationNames.first, "Animation 1");

      // Test double speed (2.0x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_rest");
      await cube.playGltfAnimation(0, speed: 2.0);
      // need to call update manually so the animation start time is recorded as
      // 3 seconds
      await FilamentApp.instance!.animationManager.update(1_000_000_000);
      // this won't have moved because it's effectively the first frame
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_start");

      // update the animation manager by 1 second
      await FilamentApp.instance!.animationManager.update(2_000_000_000);
      // cube should be at maximum height (since speed is 2.0x, 0.5s real time =
      // 1s animation time)
      await testHelper.capture(viewer.view, "gltf_animation_speed_2x_1s");

      // stop the animation
      await cube.stopGltfAnimation(0);
    });
  });

  test('play gltf animation with slower speeds', () async {
    await ViewerBuilder(testHelper, bg: kRed).execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf(
        "${testHelper.assetsDir}/cube_with_morph_targets.glb",
        addToScene: true,
      );

      final animationNames = await cube.getGltfAnimationNames();

      expect(animationNames.first, "Animation 1");

      // Test half speed (0.5x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_rest");
      await cube.playGltfAnimation(0, speed: 0.5);
      // need to call update manually so the animation start time is recorded as
      // 1 second
      await FilamentApp.instance!.animationManager.update(1_000_000_000);
      // this won't have moved because it's effectively the first frame
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_start");

      // update the animation manager by 1 second
      await FilamentApp.instance!.animationManager.update(2_000_000_000);
      // cube should be halfway to maximum height (since speed is 0.5x)
      await testHelper.capture(viewer.view, "gltf_animation_speed_0.5x_1s");

      // stop the animation
      await cube.stopGltfAnimation(0);
    });
  });

  test('play gltf animation with loop', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .setCameraLookAt(Vector3(3, 4, 15), focus: Vector3.zero())
        .execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf(
        "${testHelper.assetsDir}/cube_with_morph_targets.glb",
        addToScene: true,
      );

      final duration = await cube.getGltfAnimationDuration(0);
      final durationNanos = (duration * 1_000_000_000).toInt();
      final halfDurationNanos = durationNanos ~/ 2;

      await cube.playGltfAnimation(0, loop: true);
      final am = FilamentApp.instance!.animationManager;

      // First update records the animation start time; elapsed = 0.
      await am.update(1);

      // should show cube at rest
      await testHelper.capture(viewer.view, "gltf_loop_1");

      // should show cube at max Y-axis
      await am.update(halfDurationNanos);
      await testHelper.capture(viewer.view, "gltf_loop_2");

      // should show cube at max X-axis (subtract 1000 because)
      await am.update(durationNanos - 10000);
      await testHelper.capture(viewer.view, "gltf_loop_3");

      await am.update(durationNanos + (halfDurationNanos ~/ 2));
      await testHelper.capture(viewer.view, "gltf_loop_4");
    });
  });

  test('crossfade animations', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf(
        "${testHelper.assetsDir}/cube_with_morph_targets.glb",
        addToScene: true,
      );
      await cube.playGltfAnimation(0);
      await FilamentApp.instance!.animationManager.update(1);
      await FilamentApp.instance!.animationManager.update(500_000_000);
      await testHelper.capture(viewer.view, "gltf_crossfade_animation1");
      await cube.playGltfAnimation(1, crossfade: 0.5, replaceActive: true);
      await FilamentApp.instance!.animationManager.update(510_000_000);
      await FilamentApp.instance!.animationManager.update(750_000_000);

      await testHelper.capture(viewer.view, "gltf_crossfade_animation2");
    });
  });
}
