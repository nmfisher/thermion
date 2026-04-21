import 'dart:math';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("bone_animation");
  await testHelper.setup();

  test('setBoneTransform', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");

      await viewer.addToScene(cube);

      final boneNames = await cube.getBoneNames();
      expect(boneNames.first, "MyBone");

      await cube.setBoneTransform(0, Matrix4.rotationY(pi / 2));

      await testHelper.capture(viewer.view, "set_bone_transform");
    }, bg: kRed, cameraPosition: Vector3(0, 5, 15));
  });

  test('addBoneAnimation on a gltf asset plays a keyframed rotation', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf(
          "${testHelper.assetsDir}/cube_with_morph_targets.glb",
          addToScene: true);

      // 60-frame animation rotating MyBone from 0 to pi/2 about Y in bone space.
      const numFrames = 60;
      final frameData = <SkeletonTransform>[];
      for (int i = 0; i < numFrames; i++) {
        final angle = (pi / 2) * (i / (numFrames - 1));
        frameData.add([
          (
            rotation: Quaternion.axisAngle(Vector3(0, 1, 0), angle),
            translation: Vector3.zero()
          ),
        ]);
      }

      final animation = BoneAnimationData(["MyBone"], frameData,
          frameLengthInMs: 1000.0 / 60.0, space: Space.Bone);

      await cube.addBoneAnimation(animation);

      final am = FilamentApp.instance!.animationManager;

      // First update records the start time; renderable remains at rest.
      await am.update(1_000_000_000);
      await testHelper.capture(viewer.view, "bone_animation_start");

      // Advance ~0.5s — halfway through the 1s animation.
      await am.update(1_500_000_000);
      await testHelper.capture(viewer.view, "bone_animation_mid");

      // Advance to the end of the animation.
      await am.update(2_000_000_000);
      await testHelper.capture(viewer.view, "bone_animation_end");
    });
  });

  test('addBoneAnimation with loop wraps back to the start', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .setCameraLookAt(Vector3(3, 4, 5), focus: Vector3.zero())
        .execute((result) async {
      final viewer = result.viewer;
      final cube = await viewer.loadGltf(
          "${testHelper.assetsDir}/cube_with_morph_targets.glb",
          addToScene: true);

      final boneNames = await cube.getBoneNames();
      expect(boneNames.first, "MyBone");

      // 60-frame, 1s animation rotating MyBone from 0 → pi/2 about Y (Bone space).
      const numFrames = 60;
      const durationNanos = 1_000_000_000;
      final frameData = <SkeletonTransform>[];
      for (int i = 0; i < numFrames; i++) {
        final angle = (pi / 2) * (i / (numFrames - 1));
        frameData.add([
          (
            rotation: Quaternion.axisAngle(Vector3(0, 1, 0), angle),
            translation: Vector3.zero()
          ),
        ]);
      }

      final animation = BoneAnimationData(["MyBone"], frameData,
          frameLengthInMs: 1000.0 / 60.0, space: Space.Bone);

      await cube.addBoneAnimation(animation, loop: true);

      final am = FilamentApp.instance!.animationManager;
      final halfDurationNanos = durationNanos ~/ 2;

      // First update just records startTime; the bone is still at rest.
      await am.update(1);
      await testHelper.capture(viewer.view, "bone_animation_loop_0");

      // Midway through the first cycle.
      await am.update(halfDurationNanos - 1000);
      await testHelper.capture(
          viewer.view, "bone_animation_loop_1");

      // await am.update(durationNanos - 1000);
      // await testHelper.capture(
      //     viewer.view, "bone_animation_loop_2");

      // await am.update(durationNanos + halfDurationNanos);
      // await testHelper.capture(
      //     viewer.view, "bone_animation_loop_3");

    });
  });

  test('resetToRestPose restores original pose visually', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");
      await viewer.addToScene(cube);

      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      final am = FilamentApp.instance!.animationManager;
      final tm = FilamentApp.instance!.transformManager;

      final bones = await cube.getBones();
      expect(bones.length, 1);

      // Capture initial rest pose.
      final initialCapture =
          await testHelper.capture(viewer.view, "resetToRestPose_0_initial");
      final initialPixels = initialCapture.values.first;

      // Rotate the single bone 45 degrees around Y via TransformManager,
      // then flush to the skinning buffer via updateBoneMatrices.
      final boneEntity = bones[0];
      final originalLocal = tm.getLocalTransform(boneEntity);
      final translation = originalLocal.getTranslation();
      final rotatedLocal = Matrix4.compose(
        translation,
        Quaternion.axisAngle(Vector3(0, 1, 0), pi / 4),
        Vector3.all(1.0),
      );
      tm.setTransform(boneEntity, rotatedLocal);
      await am.updateBoneMatrices(cube);

      final rotatedCapture =
          await testHelper.capture(viewer.view, "resetToRestPose_1_rotated");
      final rotatedPixels = rotatedCapture.values.first;

      // Restore rest pose.
      await am.resetToRestPose(cube);

      final resetCapture =
          await testHelper.capture(viewer.view, "resetToRestPose_2_reset");
      final resetPixels = resetCapture.values.first;

      int initialVsRotatedDiff = 0;
      int initialVsResetDiff = 0;
      for (int i = 0; i < initialPixels.length; i++) {
        if ((initialPixels[i] - rotatedPixels[i]).abs() > 1) {
          initialVsRotatedDiff++;
        }
        if ((initialPixels[i] - resetPixels[i]).abs() > 1) {
          initialVsResetDiff++;
        }
      }

      expect(initialVsRotatedDiff, greaterThan(1000),
          reason: 'Rotated pose should look different from initial rest pose');
      expect(initialVsResetDiff, lessThan(100),
          reason: 'Reset pose should visually match initial rest pose');
    }, bg: kRed, cameraPosition: Vector3(0, 5, 15));
  });
}
