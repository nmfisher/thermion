import 'dart:io';
import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gizmo_rotation");
  await testHelper.setup();

  test('child bone rotation with updateBoneMatrices callback', () async {
    await testHelper.withViewer((viewer) async {
      // Load armature asset
      final assetData =
          File('${testHelper.assetsDir}/cube_with_morph_targets.glb')
              .readAsBytesSync();
      final asset =
          await viewer.loadGltfFromBuffer(assetData);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      // Get bone entities
      final am = FilamentApp.instance!.animationManager;
      final tm = FilamentApp.instance!.transformManager;
      final boneEntities = await asset.getBones(skinIndex: 0);
      print('Found ${boneEntities.length} bones');

      // Use the CHILD bone (index 1) - this has a parent
      final boneIndex = boneEntities.length > 1 ? 1 : 0;
      final boneEntity = boneEntities[boneIndex];
      final parentBoneIndex = am.getBoneParent(asset, 0, boneIndex);
      print('Using bone $boneIndex (entity $boneEntity), parent: $parentBoneIndex');

      // Track transforms received by callback
      final receivedTransforms = <Matrix4>[];

      // Create gizmo delegate (like skeleton viewer does)
      final gizmoDelegate = GizmoAttachmentDelegate(
        viewer: viewer,
        view: viewer.view,
        gizmoType: TransformationGizmoType.rotation,
        bonePickStrategy: BonePickStrategy.explicit,
        allowGizmoOnly: true,
        onTransformChanged: (transform) async {
          receivedTransforms.add(transform.clone());
          // The gizmo already sets the local transform via TransformManager.
          // We just need to call updateBoneMatrices() to propagate to skinning.
          am.updateBoneMatrices(asset);
        },
      );

      // Attach to bone
      await gizmoDelegate.attachTo(AttachmentTarget(
        entity: boneEntity,
        asset: asset,
        boneIndex: boneIndex,
        skinIndex: 0,
      ));

      final gizmo = gizmoDelegate.gizmo!;

      // Get initial positions
      final initialBoneWorld = tm.getWorldTransform(boneEntity);
      final initialBonePos = initialBoneWorld.getTranslation();
      print('Initial bone world position: $initialBonePos');

      await testHelper.capture(viewer.view, "child_0_initial");

      // Find a position on the rotation ring
      final viewport = await viewer.view.getViewport();
      final centerX = viewport.width ~/ 2;
      final centerY = viewport.height ~/ 2;

      // Project bone position to screen to find where gizmo is
      final camera = await viewer.getActiveCamera();
      final projMatrix = await camera.getProjectionMatrix();
      final viewMatrix = await camera.getViewMatrix();
      final clipPos = projMatrix * viewMatrix *
          Vector4(initialBonePos.x, initialBonePos.y, initialBonePos.z, 1.0);
      final ndc = clipPos / clipPos.w;
      final screenX = ((ndc.x + 1) / 2 * viewport.width).toInt();
      final screenY = ((1 - ndc.y) / 2 * viewport.height).toInt();
      print('Bone projected to screen: ($screenX, $screenY)');

      // Try to pick a gizmo axis near the bone's screen position
      int startX = screenX + 50;
      int startY = screenY;
      var pickedAxis = await gizmo.pickAxis(startX, startY);
      print('Picked axis at ($startX, $startY): $pickedAxis');

      // If no axis found, search around
      if (pickedAxis == GizmoAxis.none) {
        for (int offset = 30; offset <= 80; offset += 10) {
          for (final pos in [
            (screenX + offset, screenY),
            (screenX - offset, screenY),
            (screenX, screenY + offset),
            (screenX, screenY - offset),
          ]) {
            pickedAxis = await gizmo.pickAxis(pos.$1, pos.$2);
            if (pickedAxis != GizmoAxis.none) {
              startX = pos.$1;
              startY = pos.$2;
              print('Found axis $pickedAxis at ($startX, $startY)');
              break;
            }
          }
          if (pickedAxis != GizmoAxis.none) break;
        }
      }

      // Start drag
      final dragStarted = await gizmo.startDrag(startX, startY);
      print('Drag started: $dragStarted, active axis: ${gizmo.isActive}');

      await testHelper.capture(viewer.view, "child_1_drag_started");

      // Track positions during rotation
      final bonePositions = <Vector3>[];

      // Simulate rotation
      for (int i = 0; i <= 20; i++) {
        final angle = (i / 20) * math.pi / 2; // 90 degree rotation
        final dragX = screenX + (50 * math.cos(angle)).toInt();
        final dragY = screenY + (50 * math.sin(angle)).toInt();

        if (gizmo.isActive) {
          await gizmo.updateDrag(dragX, dragY);

          // The gizmo already sets the local transform via TransformManager.
          // We just need to call updateBoneMatrices() to propagate to skinning.
          am.updateBoneMatrices(asset);
        }

        // Get current bone world position
        final boneWorld = tm.getWorldTransform(boneEntity);
        final bonePos = boneWorld.getTranslation();
        bonePositions.add(bonePos.clone());

        if (i % 5 == 0) {
          await testHelper.capture(viewer.view, "child_2_rot_${i.toString().padLeft(2, '0')}");
          print('Frame $i: bone pos = $bonePos');
        }
      }

      await gizmo.endDrag();
      await testHelper.capture(viewer.view, "child_3_ended");

      // Analyze drift
      print('\n--- Child Bone Position Analysis ---');
      final firstPos = bonePositions.first;
      double maxDrift = 0;
      for (int i = 0; i < bonePositions.length; i++) {
        final drift = bonePositions[i].distanceTo(firstPos);
        if (drift > maxDrift) maxDrift = drift;
      }
      print('Maximum bone position drift: ${maxDrift.toStringAsFixed(6)}');
      print('Received ${receivedTransforms.length} transform callbacks');

      await gizmoDelegate.dispose();
    }, cameraPosition: Vector3(3, 3, 5));
  });

  test('gizmo should not move during rotation', () async {
    await testHelper.withViewer((viewer) async {
      // Load armature asset
      final assetData =
          File('${testHelper.assetsDir}/cube_with_morph_targets.glb')
              .readAsBytesSync();
      final asset =
          await viewer.loadGltfFromBuffer(assetData);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      // Get bone entities
      final boneEntities = await asset.getBones(skinIndex: 0);
      print('Found ${boneEntities.length} bones');

      if (boneEntities.isEmpty) {
        fail('No bones found in asset');
      }

      // Use the first bone (index 0)
      final boneIndex = 0;
      final boneEntity = boneEntities[boneIndex];
      print('Attaching gizmo to bone $boneIndex (entity $boneEntity)');

      // Create gizmo
      final gizmo = TransformationGizmo(viewer);
      await gizmo.create(type: TransformationGizmoType.rotation);

      // Attach to bone
      gizmo.attachTo(boneEntity);

      // Get initial gizmo position
      final tm = FilamentApp.instance!.transformManager;

      // Capture initial state
      await testHelper.capture(viewer.view, "0_initial");

      // Get the gizmo root entity position (we need to access it indirectly)
      final initialBoneTransform = tm.getWorldTransform(boneEntity);
      final initialBonePos = initialBoneTransform.getTranslation();
      print('Initial bone world position: $initialBonePos');

      // Simulate rotation drag
      // First, start a drag on the Y axis (screen coordinates near center)
      final viewport = await viewer.view.getViewport();
      final centerX = viewport.width ~/ 2;
      final centerY = viewport.height ~/ 2;

      print('\n--- Starting rotation simulation ---');
      print('Viewport: ${viewport.width}x${viewport.height}');
      print('Center: ($centerX, $centerY)');

      // Simulate clicking on the Y-axis ring (green ring)
      // We'll use coordinates slightly offset from center to hit the ring
      final ringOffset = 50; // pixels from center to hit the ring
      final startX = centerX + ringOffset;
      final startY = centerY;

      // Check what axis we'd pick at this location
      final pickedAxis = await gizmo.pickAxis(startX, startY);
      print('Picked axis at ($startX, $startY): $pickedAxis');

      // Start the drag
      final dragStarted = await gizmo.startDrag(startX, startY);
      print('Drag started: $dragStarted');

      if (!dragStarted) {
        // Try a different position - maybe we need to be on the actual ring
        print('Trying alternative positions...');
        for (int offset = 30; offset <= 100; offset += 10) {
          for (final pos in [
            (centerX + offset, centerY),
            (centerX - offset, centerY),
            (centerX, centerY + offset),
            (centerX, centerY - offset),
          ]) {
            final axis = await gizmo.pickAxis(pos.$1, pos.$2);
            if (axis != GizmoAxis.none) {
              print('Found axis $axis at offset $offset, pos $pos');
              break;
            }
          }
        }
      }

      // For testing, let's manually simulate the drag even if pickAxis didn't work
      // by directly setting internal state (this is a diagnostic test)

      // Capture frame after starting drag
      await testHelper.capture(viewer.view, "1_drag_started");

      // Track gizmo position during rotation
      final positions = <Vector3>[];

      // Simulate rotation by calling updateDrag with different positions
      // Move in a circular arc
      for (int i = 0; i <= 36; i++) {
        final angle = (i / 36) * math.pi / 2; // 90 degree rotation
        final dragX = centerX + (ringOffset * math.cos(angle)).toInt();
        final dragY = centerY + (ringOffset * math.sin(angle)).toInt();

        if (gizmo.isActive) {
          await gizmo.updateDrag(dragX, dragY);
        }

        // Get bone position after update
        final boneTransform = tm.getWorldTransform(boneEntity);
        final bonePos = boneTransform.getTranslation();
        positions.add(bonePos.clone());

        // Capture every 9th frame
        if (i % 9 == 0) {
          await testHelper.capture(viewer.view, "2_rotation_${i.toString().padLeft(2, '0')}");
          print('Frame $i: bone pos = $bonePos');
        }
      }

      // End drag
      await gizmo.endDrag();
      await testHelper.capture(viewer.view, "3_drag_ended");

      // Analyze position drift
      print('\n--- Position Analysis ---');
      final firstPos = positions.first;
      double maxDrift = 0;
      for (int i = 0; i < positions.length; i++) {
        final drift = positions[i].distanceTo(firstPos);
        if (drift > maxDrift) maxDrift = drift;
        if (drift > 0.001) {
          print('Frame $i: drift = ${drift.toStringAsFixed(6)}');
        }
      }
      print('Maximum position drift: ${maxDrift.toStringAsFixed(6)}');

      // The bone position should not change during pure rotation
      expect(maxDrift, lessThan(0.01),
          reason: 'Bone position should not drift during rotation');

      // Cleanup
      await gizmo.dispose();
    }, cameraPosition: Vector3(3, 3, 5));
  });

  test('manual rotation test - direct API calls', () async {
    await testHelper.withViewer((viewer) async {
      // Load armature asset
      final assetData =
          File('${testHelper.assetsDir}/cube_with_morph_targets.glb')
              .readAsBytesSync();
      final asset =
          await viewer.loadGltfFromBuffer(assetData);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(
          direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      final tm = FilamentApp.instance!.transformManager;
      final boneEntities = await asset.getBones(skinIndex: 0);

      final boneEntity = boneEntities[0];

      // Get initial transform
      final initialWorld = tm.getWorldTransform(boneEntity);
      final initialPos = initialWorld.getTranslation();
      final initialRot = Quaternion.fromRotation(initialWorld.getRotation());
      print('Initial: pos=$initialPos, rot=$initialRot');

      await testHelper.capture(viewer.view, "manual_0_initial");

      // Apply rotation directly using the same math as the gizmo
      for (int i = 1; i <= 10; i++) {
        final angle = (i / 10) * (math.pi / 4); // 45 degree total
        final axisRotation = Quaternion.axisAngle(Vector3(0, 1, 0), angle);
        final newRotation = axisRotation * initialRot;

        // Extract scale from initial transform
        final scaleX = math.sqrt(
            initialWorld[0] * initialWorld[0] +
                initialWorld[1] * initialWorld[1] +
                initialWorld[2] * initialWorld[2]);
        final scaleY = math.sqrt(
            initialWorld[4] * initialWorld[4] +
                initialWorld[5] * initialWorld[5] +
                initialWorld[6] * initialWorld[6]);
        final scaleZ = math.sqrt(
            initialWorld[8] * initialWorld[8] +
                initialWorld[9] * initialWorld[9] +
                initialWorld[10] * initialWorld[10]);
        final scale = Vector3(scaleX, scaleY, scaleZ);

        // Compose new world transform (same position, new rotation)
        final newWorldTransform =
            Matrix4.compose(initialPos, newRotation, scale);

        // Convert to local (this is what the gizmo does)
        final parent = tm.getParent(boneEntity);
        Matrix4 localTransform;
        if (parent == null) {
          localTransform = newWorldTransform;
        } else {
          final parentWorld = tm.getWorldTransform(parent);
          final parentInv = parentWorld.clone()..invert();
          localTransform = parentInv * newWorldTransform;
        }

        // Set the transform
        tm.setTransform(boneEntity, localTransform);

        // Read back the world transform
        final resultWorld = tm.getWorldTransform(boneEntity);
        final resultPos = resultWorld.getTranslation();

        final drift = resultPos.distanceTo(initialPos);
        print('Step $i: angle=${(angle * 180 / math.pi).toStringAsFixed(1)}°, '
            'resultPos=$resultPos, drift=${drift.toStringAsFixed(6)}');

        await testHelper.capture(viewer.view, "manual_${i}_rot");
      }
    }, cameraPosition: Vector3(3, 3, 5));
  });
}
