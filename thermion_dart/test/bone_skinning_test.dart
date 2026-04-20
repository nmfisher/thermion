import 'dart:io';
import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

/// Test to investigate how bone skinning works in Filament:
/// - Does TransformManager + updateBoneMatrices() affect the mesh?
/// - Does RenderableManager.setBones() directly affect the mesh?
void main() async {
  final testHelper = TestHelper("bone_skinning");
  await testHelper.setup();

  /// Helper to find the renderable entity (the skinned mesh) in an asset
  Future<ThermionEntity?> findRenderableEntity(ThermionAsset asset) async {
    final children = await asset.getChildEntities();
    final rm = FilamentApp.instance!.renderableManager;
    for (final child in children) {
      if (rm.isRenderable(child)) {
        print('Found renderable entity: $child');
        return child;
      }
    }
    // Also check the root entity
    if (rm.isRenderable(asset.entity)) {
      print('Root entity is renderable: ${asset.entity}');
      return asset.entity;
    }
    return null;
  }

  test('Test 1: TransformManager + updateBoneMatrices()', () async {
    await testHelper.withViewer((viewer) async {
      // Load armature asset
      final assetData =
          File('${testHelper.testDir}/assets/cube_with_armature.glb')
              .readAsBytesSync();
      final asset = await viewer.loadGltfFromBuffer(assetData, keepData: true);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      final am = FilamentApp.instance!.animationManager;
      final tm = FilamentApp.instance!.transformManager;
      final rm = FilamentApp.instance!.renderableManager;

      // Get bone entities
      final boneEntities = am.getBoneEntities(asset, 0);
      print('Found ${boneEntities.length} bone entities');
      for (int i = 0; i < boneEntities.length; i++) {
        final name =
            await FilamentApp.instance!.getNameForEntity(boneEntities[i]);
        print('  Bone $i: entity ${boneEntities[i]}, name: $name');
      }

      // Find renderable entity
      final renderableEntity = await findRenderableEntity(asset);
      print('Renderable entity: $renderableEntity');

      // Check all child entities
      final children = await asset.getChildEntities();
      print('\nAll child entities:');
      for (final child in children) {
        final name = await FilamentApp.instance!.getNameForEntity(child);
        final isRenderable = rm.isRenderable(child);
        print('  Entity $child: name=$name, isRenderable=$isRenderable');
      }

      // Capture initial state
      await testHelper.capture(viewer.view, "test1_0_initial");

      // Get initial bone transform
      final boneEntity = boneEntities[0];
      final initialLocal = tm.getLocalTransform(boneEntity);
      final initialWorld = tm.getWorldTransform(boneEntity);
      print('\nInitial bone 0 local transform:\n$initialLocal');
      print('Initial bone 0 world transform:\n$initialWorld');

      // Apply rotation via TransformManager
      print('\n--- Applying rotation via TransformManager ---');

      // Compose new local transform (rotation only, keep translation)
      final translation = initialLocal.getTranslation();
      final newLocal = Matrix4.compose(
        translation,
        Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 4),
        Vector3.all(1.0),
      );

      print('Setting new local transform:\n$newLocal');
      tm.setTransform(boneEntity, newLocal);

      // Verify transform was set
      final afterSetLocal = tm.getLocalTransform(boneEntity);
      print('After setTransform, local:\n$afterSetLocal');

      await testHelper.capture(viewer.view, "test1_1_after_setTransform");

      // Now call updateBoneMatrices
      print('\n--- Calling updateBoneMatrices ---');
      am.updateBoneMatrices(asset);

      await testHelper.capture(viewer.view, "test1_2_after_updateBoneMatrices");

      // Apply more rotation
      for (int i = 1; i <= 4; i++) {
        final angle = (i / 4) * math.pi / 2; // Up to 90 degrees
        final rotatedLocal = Matrix4.compose(
          translation,
          Quaternion.axisAngle(Vector3(0, 1, 0), angle),
          Vector3.all(1.0),
        );
        tm.setTransform(boneEntity, rotatedLocal);
        am.updateBoneMatrices(asset);

        await testHelper.capture(viewer.view, "test1_3_rot_${i * 25}deg");
        print(
            'Captured at ${(angle * 180 / math.pi).toStringAsFixed(0)} degrees');
      }

      print('\n=== Test 1 Complete ===');
      print('Check test/output/bone_skinning/ for screenshots');
      print(
          'If the mesh deforms, TransformManager + updateBoneMatrices works for skinning');
    }, cameraPosition: Vector3(3, 3, 5));
  });

  test('Test 2: RenderableManager.setBones() directly', () async {
    await testHelper.withViewer((viewer) async {
      // Load armature asset
      final assetData =
          File('${testHelper.testDir}/assets/cube_with_armature.glb')
              .readAsBytesSync();
      final asset = await viewer.loadGltfFromBuffer(assetData, keepData: true);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      final am = FilamentApp.instance!.animationManager;
      final rm = FilamentApp.instance!.renderableManager;

      // Get bone entities and find renderable
      final boneEntities = am.getBoneEntities(asset, 0);
      final renderableEntity = await findRenderableEntity(asset);

      if (renderableEntity == null) {
        fail('Could not find renderable entity');
      }

      print(
          'Found ${boneEntities.length} bones, renderable: $renderableEntity');

      // Capture initial state
      await testHelper.capture(viewer.view, "test2_0_initial");

      // Try calling setBones directly on the renderable entity
      print('\n--- Calling RenderableManager.setBones() directly ---');

      // Create bone transforms - we need one transform per bone
      // These should be root-to-node transforms (model space)
      final boneCount = boneEntities.length;
      print('Creating $boneCount bone transforms');

      // Start with identity transforms
      final transforms = List.generate(boneCount, (_) => Matrix4.identity());

      // Apply rotation to first bone
      transforms[0] = Matrix4.rotationY(math.pi / 4);

      print('Setting bones with rotation on bone 0');
      await rm.setBones(renderableEntity, transforms);

      await testHelper.capture(viewer.view, "test2_1_after_setBones");

      // Apply more rotation
      for (int i = 1; i <= 4; i++) {
        final angle = (i / 4) * math.pi / 2;
        transforms[0] = Matrix4.rotationY(angle);
        await rm.setBones(renderableEntity, transforms);

        await testHelper.capture(viewer.view, "test2_2_rot_${i * 25}deg");
        print(
            'Captured at ${(angle * 180 / math.pi).toStringAsFixed(0)} degrees');
      }

      print('\n=== Test 2 Complete ===');
      print('Check test/output/bone_skinning/ for screenshots');
      print('If the mesh deforms, direct setBones() works for skinning');
    }, cameraPosition: Vector3(3, 3, 5));
  });

  test('Test 3: Compare - what do the bone transforms look like?', () async {
    await testHelper.withViewer((viewer) async {
      // Load armature asset
      final assetData =
          File('${testHelper.testDir}/assets/cube_with_armature.glb')
              .readAsBytesSync();
      final asset = await viewer.loadGltfFromBuffer(assetData, keepData: true);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      final am = FilamentApp.instance!.animationManager;
      final tm = FilamentApp.instance!.transformManager;

      // Get bone entities
      final boneEntities = am.getBoneEntities(asset, 0);

      print('\n=== Bone Transform Analysis ===\n');

      for (int i = 0; i < boneEntities.length; i++) {
        final entity = boneEntities[i];
        final name = await FilamentApp.instance!.getNameForEntity(entity);
        final parent = tm.getParent(entity);
        final parentName = parent != null
            ? await FilamentApp.instance!.getNameForEntity(parent)
            : 'none';

        final local = tm.getLocalTransform(entity);
        final world = tm.getWorldTransform(entity);

        print('Bone $i: $name');
        print('  Parent: $parentName (entity: $parent)');
        print('  Local position: ${local.getTranslation()}');
        print('  World position: ${world.getTranslation()}');

        // Get inverse bind matrix
        final invBind = am.getInverseBindMatrix(asset, 0, i);
        print(
            '  Inverse bind matrix diagonal: [${invBind[0]}, ${invBind[5]}, ${invBind[10]}, ${invBind[15]}]');
        print(
            '  Inverse bind translation: ${Vector3(invBind[12], invBind[13], invBind[14])}');
        print('');
      }

      // Get rest transforms (returns flat list of 16 floats per bone)
      final restTransforms = am.getRestLocalTransforms(asset, 0);
      final boneCount = boneEntities.length;
      print(
          '\nRest transforms (raw floats, $boneCount bones, ${restTransforms.length} values):');
      for (int i = 0; i < boneCount && i * 16 < restTransforms.length; i++) {
        final offset = i * 16;
        // Translation is at [12], [13], [14] in a 4x4 column-major matrix
        final tx = restTransforms[offset + 12];
        final ty = restTransforms[offset + 13];
        final tz = restTransforms[offset + 14];
        print('  Bone $i rest translation: ($tx, $ty, $tz)');
      }

      await testHelper.capture(viewer.view, "test3_analysis");

      print('\n=== Analysis Complete ===');
    }, cameraPosition: Vector3(3, 3, 5));
  });

  test('Test 4: setBones on bone entity vs mesh entity', () async {
    await testHelper.withViewer((viewer) async {
      // Load armature asset
      final assetData =
          File('${testHelper.testDir}/assets/cube_with_armature.glb')
              .readAsBytesSync();
      final asset = await viewer.loadGltfFromBuffer(assetData, keepData: true);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      final am = FilamentApp.instance!.animationManager;
      final rm = FilamentApp.instance!.renderableManager;

      // Get bone entities
      final boneEntities = am.getBoneEntities(asset, 0);
      print('Bone entities: $boneEntities');

      // Check if bone entities are renderable
      print('\nChecking if bone entities are renderable:');
      for (int i = 0; i < boneEntities.length; i++) {
        final isRenderable = rm.isRenderable(boneEntities[i]);
        print('  Bone $i (${boneEntities[i]}): isRenderable = $isRenderable');
      }

      // Find mesh entity by looking for renderable children
      final children = await asset.getChildEntities();
      ThermionEntity? meshEntity;
      for (final child in children) {
        if (rm.isRenderable(child) && !boneEntities.contains(child)) {
          final name = await FilamentApp.instance!.getNameForEntity(child);
          print('\nFound mesh entity: $child (name: $name)');
          meshEntity = child;
          break;
        }
      }

      if (meshEntity == null) {
        // Maybe the root entity is the mesh?
        if (rm.isRenderable(asset.entity)) {
          meshEntity = asset.entity;
          print('Root entity is the mesh: $meshEntity');
        }
      }

      await testHelper.capture(viewer.view, "test4_0_initial");

      if (meshEntity != null) {
        print('\n--- Testing setBones on mesh entity $meshEntity ---');
        final transforms =
            List.generate(boneEntities.length, (_) => Matrix4.identity());
        transforms[0] = Matrix4.rotationY(math.pi / 4);

        try {
          await rm.setBones(meshEntity, transforms);
          await testHelper.capture(viewer.view, "test4_1_setBones_on_mesh");
          print('setBones on mesh entity succeeded');
        } catch (e) {
          print('setBones on mesh entity failed: $e');
        }
      }

      // Reset and try on bone entity
      am.resetToRestPose(asset);
      await testHelper.capture(viewer.view, "test4_2_reset");

      print('\n--- Testing setBones on bone entity ${boneEntities[0]} ---');
      final transforms = [Matrix4.rotationY(math.pi / 4)];
      try {
        await rm.setBones(boneEntities[0], transforms);
        await testHelper.capture(viewer.view, "test4_3_setBones_on_bone");
        print('setBones on bone entity succeeded');
      } catch (e) {
        print('setBones on bone entity failed: $e');
      }

      print('\n=== Test 4 Complete ===');
    }, cameraPosition: Vector3(3, 3, 5));
  });

  test('Test 5: resetToRestPose should restore original pose visually',
      () async {
    await testHelper.withViewer((viewer) async {
      // Load armature asset
      final assetData =
          File('${testHelper.testDir}/assets/cube_with_armature.glb')
              .readAsBytesSync();
      final asset = await viewer.loadGltfFromBuffer(assetData, keepData: true);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      final am = FilamentApp.instance!.animationManager;
      final tm = FilamentApp.instance!.transformManager;

      // Get bone entities
      final boneEntities = am.getBoneEntities(asset, 0);
      print('Found ${boneEntities.length} bones');

      // Capture 1: Initial rest pose
      print('\n--- Capturing initial rest pose ---');
      final initialCapture =
          await testHelper.capture(viewer.view, "test5_0_initial");
      final initialPixels = initialCapture.values.first;
      final viewport = await viewer.view.getViewport();
      print('Captured initial: ${viewport.width}x${viewport.height}');

      // Rotate the first bone significantly (45 degrees around Y)
      final boneEntity = boneEntities[0];
      final boneName = await FilamentApp.instance!.getNameForEntity(boneEntity);
      print('\n--- Rotating $boneName by 45 degrees ---');

      final originalLocal = tm.getLocalTransform(boneEntity);
      final translation = originalLocal.getTranslation();
      final rotatedLocal = Matrix4.compose(
        translation,
        Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 4),
        Vector3.all(1.0),
      );
      tm.setTransform(boneEntity, rotatedLocal);
      am.updateBoneMatrices(asset);

      // Capture 2: After rotation (mesh should be deformed)
      final rotatedCapture =
          await testHelper.capture(viewer.view, "test5_1_after_rotation");
      final rotatedPixels = rotatedCapture.values.first;
      print('Captured rotated pose');

      // Now call resetToRestPose
      print('\n--- Calling resetToRestPose ---');
      am.resetToRestPose(asset);

      // Capture 3: After reset (should match initial)
      final resetCapture =
          await testHelper.capture(viewer.view, "test5_2_after_reset");
      final resetPixels = resetCapture.values.first;
      print('Captured reset pose');

      // Compare initial vs rotated (should be different)
      print('\n--- Comparing captures ---');
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

      final totalPixelValues = initialPixels.length;
      final rotatedDiffPercent =
          (initialVsRotatedDiff / totalPixelValues * 100).toStringAsFixed(2);
      final resetDiffPercent =
          (initialVsResetDiff / totalPixelValues * 100).toStringAsFixed(2);

      print(
          'Initial vs Rotated: $initialVsRotatedDiff different values ($rotatedDiffPercent%)');
      print(
          'Initial vs Reset: $initialVsResetDiff different values ($resetDiffPercent%)');

      // The rotated pose should be significantly different from initial
      expect(initialVsRotatedDiff, greaterThan(1000),
          reason: 'Rotated pose should look different from initial rest pose');

      // The reset pose should match the initial pose (with small tolerance for floating point)
      expect(initialVsResetDiff, lessThan(100),
          reason: 'Reset pose should visually match initial rest pose');

      print('\n=== Test 5 Complete ===');
      print(
          'SUCCESS: resetToRestPose correctly restored the visual appearance');
    }, cameraPosition: Vector3(3, 3, 5));
  });
}
