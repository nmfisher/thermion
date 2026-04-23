import 'dart:async';
import 'dart:io';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("bone_picking");
  await testHelper.setup();

  test('pick bone with screen-space picking', () async {
    await testHelper.withViewer((viewer) async {
      // 1. Load armature asset
      final assetData =
          File('${testHelper.testDir}/assets/cube_with_morph_targets.glb')
              .readAsBytesSync();
      final asset =
          await viewer.loadGltfFromBuffer(assetData);
      await viewer.addToScene(asset);

      // Add lighting so we can see the cube
      await viewer.addDirectLight(DirectLight.sun(
        direction: Vector3(0.7, -1, -0.8).normalized(),
        intensity: 100000.0,
      ));

      // 2. Create bone visualizer
      final boneVisualizer = BoneVisualizer(
        viewer: viewer,
        asset: asset,
        skinIndex: 0,
        sphereRadius: 0.1,
      );
      await boneVisualizer.show();

      // Capture initial frame to see scene
      await testHelper.capture(viewer.view, "bone_scene_initial");

      print('Asset entity: ${asset.entity}');
      print('Bone visualizer visible: ${boneVisualizer.isVisible}');

      // 3. Get bone world positions for logging
      final boneEntities = await asset.getBones(skinIndex: 0);
      final tm = FilamentApp.instance!.transformManager;

      print('Found ${boneEntities.length} bones');

      // 4. Test screen-space picking for ALL bones (including bone 0 inside mesh!)
      for (int boneIndex = 0; boneIndex < boneEntities.length; boneIndex++) {
        final boneEntity = boneEntities[boneIndex];
        if (boneEntity == 0) {
          print('Bone $boneIndex: entity is 0, skipping');
          continue;
        }

        // Get world position and project to screen
        final transform = await tm.getWorldTransform(boneEntity);
        final worldPos = transform.getTranslation();

        final camera = await viewer.getActiveCamera();
        final viewport = await viewer.view.getViewport();
        final projMatrix = await camera.getProjectionMatrix();
        final viewMatrix = await camera.getViewMatrix();

        final clipPos = (projMatrix * viewMatrix) *
            Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
        final ndcPos = clipPos.xyz / clipPos.w;

        final screenX = ((ndcPos.x + 1) / 2 * viewport.width).toInt();
        final screenY = ((1 - ndcPos.y) / 2 * viewport.height).toInt();

        print('Bone $boneIndex: worldPos=$worldPos -> screen=($screenX, $screenY)');

        // 5. Use screen-space picking (bypasses depth buffer!)
        final pickedBoneIndex =
            await boneVisualizer.pickBoneAtScreen(screenX, screenY);

        print('  -> screen-space pick: boneIndex=$pickedBoneIndex');

        // Render a frame to capture
        await testHelper.capture(viewer.view, "bone_pick_$boneIndex");

        // 6. Verify screen-space picking works for ALL bones
        expect(pickedBoneIndex, boneIndex,
            reason: 'Screen-space picking at bone $boneIndex should return that bone');

        // Highlight and capture
        await boneVisualizer.highlightBone(pickedBoneIndex);
        await testHelper.capture(viewer.view, "bone_highlighted_$boneIndex");
      }

      await boneVisualizer.hide();
    }, cameraPosition: Vector3(3, 3, 5));
  });

  test('pick bone with empty space behind', () async {
    await testHelper.withViewer((viewer) async {
      // Load asset
      final assetData =
          File('${testHelper.testDir}/assets/cube_with_morph_targets.glb')
              .readAsBytesSync();
      final asset =
          await viewer.loadGltfFromBuffer(assetData);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
        direction: Vector3(0.7, -1, -0.8).normalized(),
        intensity: 100000.0,
      ));

      // Create bone visualizer
      final boneVisualizer = BoneVisualizer(
        viewer: viewer,
        asset: asset,
        skinIndex: 0,
        sphereRadius: 0.1, // Larger for easier picking
      );
      await boneVisualizer.show();

      // Hide mesh to isolate bone sphere picking
      await viewer.removeFromScene(asset);

      // Position camera to look at bone 1 from above - so empty space is behind it
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(
        Vector3(0, 5, 0.1), // Camera above looking down
        focus: Vector3(0, 1, 0), // Focus on bone 1 position
        up: Vector3(0, 0, -1),
      );

      await testHelper.capture(viewer.view, "bone_empty_behind");

      // Pick at center of screen (should hit bone 1 with empty space behind)
      final viewport = await viewer.view.getViewport();
      final centerX = viewport.width ~/ 2;
      final centerY = viewport.height ~/ 2;

      print('Picking at center: ($centerX, $centerY)');

      final completer = Completer<PickResult>();
      await viewer.view.pick(centerX, centerY, completer.complete);

      for (int i = 0; i < 10; i++) {
        await testHelper.capture(viewer.view, "bone_empty_pick_$i");
        if (completer.isCompleted) break;
      }

      expect(completer.isCompleted, true);
      final result = await completer.future;
      final pickedBoneIndex =
          boneVisualizer.getBoneIndexForEntity(result.entity);

      print('Picked entity=${result.entity}, depth=${result.depth}, '
          'mappedBone=$pickedBoneIndex');

      // Should pick bone 1, not return null (which would indicate empty space)
      expect(pickedBoneIndex, isNotNull,
          reason: 'Should pick bone sphere, not empty space');

      // Highlight the picked bone and capture
      if (pickedBoneIndex != null) {
        await boneVisualizer.highlightBone(pickedBoneIndex);
        await testHelper.capture(viewer.view, "bone_empty_highlighted");
      }

      await boneVisualizer.hide();
    }, cameraPosition: Vector3(0, 5, 0.1));
  });
}
