import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("renderable_manager");
  await testHelper.setup();

  group("RenderableManager tests", () {
    test('hasComponent and isRenderable', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Cube entity should have a renderable component
        expect(renderableManager.hasComponent(cube.entity), true);
        expect(renderableManager.isRenderable(cube.entity), true);
        expect(renderableManager.empty(), false);
        expect(renderableManager.getComponentCount(), greaterThan(0));
      });
    });

    test('getPrimitiveCount', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // A cube should have primitives
        final primitiveCount = renderableManager.getPrimitiveCount(cube.entity);
        expect(primitiveCount, greaterThan(0));
      });
    });

    test('material instance management', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addSun().addCube(color: kRed);

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Capture to verify color change
        await testHelper.capture(result.viewer.view, "material_default");

        // Get the current material instance
        final originalMaterial = await renderableManager.getMaterialInstanceAt(cube.entity, 0);
        expect(originalMaterial, isNotNull);

        // Create a new material instance with a different color
        final newMaterial = await FilamentApp.instance!.createUbershaderMaterialInstance();
        await newMaterial.setParameterFloat4('baseColorFactor', 0.0, 1.0, 0.0, 1.0); // Green

        // Set the new material
        final success = await renderableManager.setMaterialInstanceAt(cube.entity, 0, newMaterial);
        expect(success, true);

        // Verify the material was changed
        final updatedMaterial = await renderableManager.getMaterialInstanceAt(cube.entity, 0);
        expect(updatedMaterial, isNotNull);

        // Capture to verify color change
        await testHelper.capture(result.viewer.view, "material_changed_to_green");

        // Clear the material instance
        await renderableManager.clearMaterialInstanceAt(cube.entity, 0);
      });
    });

    test('bounding box operations', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Get the axis-aligned bounding box
        final aabb = renderableManager.getAxisAlignedBoundingBox(cube.entity);
        expect(aabb, isNotNull);
        expect(aabb.center, isNotNull);
        expect(aabb.min, isNotNull);
        expect(aabb.max, isNotNull);

        // Test getBoundingBox alias
        final aabb2 = renderableManager.getBoundingBox(cube.entity);
        expect(aabb2.center.x, equals(aabb.center.x));
        expect(aabb2.center.y, equals(aabb.center.y));
        expect(aabb2.center.z, equals(aabb.center.z));

        // Set a new bounding box
        final newAabb = Aabb3.centerAndHalfExtents(Vector3(0, 0, 0), Vector3(2, 2, 2));
        await renderableManager.setAxisAlignedBoundingBox(cube.entity, newAabb);

        // Verify the bounding box was updated
        // Extract center and halfExtents from the updated AABB
        final updatedAabb = renderableManager.getAxisAlignedBoundingBox(cube.entity);
        final updatedCenter = Vector3.zero();
        final updatedHalfExtents = Vector3.zero();
        updatedAabb.copyCenterAndHalfExtents(updatedCenter, updatedHalfExtents);

        expect(updatedHalfExtents.x, closeTo(2.0, 0.01));
        expect(updatedHalfExtents.y, closeTo(2.0, 0.01));
        expect(updatedHalfExtents.z, closeTo(2.0, 0.01));
      });
    });

    test('layer mask and visibility', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Get initial layer mask
        final initialMask = renderableManager.getLayerMask(cube.entity);
        expect(initialMask, isNotNull);

        // Set a specific layer mask (set bit 2, clear bit 0)
        await renderableManager.setLayerMask(cube.entity, 0x05, 0x04);

        // Verify layer mask changed
        final updatedMask = renderableManager.getLayerMask(cube.entity);
        expect(updatedMask & 0x04, equals(0x04)); // Bit 2 should be set

        // Test setVisibilityLayer convenience method
        await renderableManager.setVisibilityLayer(cube.entity, 3);
      });
    });

    test('priority and channel', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Set priority (no getter exposed; just verify the call succeeds)
        await renderableManager.setPriority(cube.entity, 5);

        // Set channel (no getter exposed; just verify the call succeeds)
        await renderableManager.setChannel(cube.entity, 2);
      });
    });

    test('culling control', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Disable culling
        await renderableManager.setCulling(cube.entity, false);

        // Enable culling
        await renderableManager.setCulling(cube.entity, true);
      });
    });

    test('fog control', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Check initial fog state
        final initialFogEnabled = renderableManager.getFogEnabled(cube.entity);
        expect(initialFogEnabled, isA<bool>());

        // Disable fog
        await renderableManager.setFogEnabled(cube.entity, false);
        expect(renderableManager.getFogEnabled(cube.entity), false);

        // Enable fog
        await renderableManager.setFogEnabled(cube.entity, true);
        expect(renderableManager.getFogEnabled(cube.entity), true);
      });
    });

    test('light channels', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Enable light channel 2
        await renderableManager.setLightChannel(cube.entity, 2, true);
        final channel2Enabled = renderableManager.getLightChannel(cube.entity, 2);
        expect(channel2Enabled, true);

        // Disable light channel 2
        await renderableManager.setLightChannel(cube.entity, 2, false);
        final channel2Disabled = renderableManager.getLightChannel(cube.entity, 2);
        expect(channel2Disabled, false);

        // Channel 0 is enabled by default
        final channel0Enabled = renderableManager.getLightChannel(cube.entity, 0);
        expect(channel0Enabled, true);
      });
    });

    test('shadow controls', () async {
      final builder = ViewerBuilder(testHelper)
          .setRenderTargetEnabled(true)
          .setShadowsEnabled(true)
          .addSun(intensity: 50000, castShadows: true, direction: Vector3(1, -1, 0).normalized())
          .addCube(castShadows: true)
          .addPlane(receiveShadows: true);

      await builder.execute((result) async {
        final cube = result.assets[0];
        final plane = result.assets[1];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Verify cube casts shadows
        expect(renderableManager.isShadowCaster(cube.entity), true);

        // Disable shadow casting
        await renderableManager.setCastShadows(cube.entity, false);
        expect(renderableManager.isShadowCaster(cube.entity), false);

        await testHelper.capture(result.viewer.view, "shadows_cast_disabled");

        // Re-enable shadow casting
        await renderableManager.setCastShadows(cube.entity, true);
        expect(renderableManager.isShadowCaster(cube.entity), true);

        await testHelper.capture(result.viewer.view, "shadows_cast_enabled");

        // Test shadow receiving on plane
        expect(renderableManager.isShadowReceiver(plane.entity), true);

        await renderableManager.setReceiveShadows(plane.entity, false);
        expect(renderableManager.isShadowReceiver(plane.entity), false);

        await testHelper.capture(result.viewer.view, "shadows_receive_disabled");

        await renderableManager.setReceiveShadows(plane.entity, true);
        expect(renderableManager.isShadowReceiver(plane.entity), true);

        await testHelper.capture(result.viewer.view, "shadows_receive_enabled");
      });
    });

    test('screen space contact shadows', () async {
      final builder = ViewerBuilder(testHelper)
          .setRenderTargetEnabled(true)
          .setShadowsEnabled(true)
          .addSun(intensity: 50000, castShadows: true, direction: Vector3(1, -1, 0).normalized())
          .addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Enable screen space contact shadows
        await renderableManager.setScreenSpaceContactShadows(cube.entity, true);

        await testHelper.capture(result.viewer.view, "sscs_enabled");

        // Disable screen space contact shadows
        await renderableManager.setScreenSpaceContactShadows(cube.entity, false);

        await testHelper.capture(result.viewer.view, "sscs_disabled");
      });
    });

    test('blend order operations', () async {
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        final primitiveCount = renderableManager.getPrimitiveCount(cube.entity);

        if (primitiveCount > 0) {
          // Set blend order for first primitive
          await renderableManager.setBlendOrderAt(cube.entity, 0, 100);

          // Set global blend order enabled
          await renderableManager.setGlobalBlendOrderEnabledAt(cube.entity, 0, true);

          // Set global blend order disabled
          await renderableManager.setGlobalBlendOrderEnabledAt(cube.entity, 0, false);
        }
      });
    });

    test('setBonesFromMat4 deforms a skinned mesh', () async {
      // cube_with_morph_targets.glb is a skinned cube with a single joint
      // ("MyBone"). Per its glTF definition, the Armature root node is the
      // asset entity and the Cube mesh is a child; only the mesh has a
      // renderable component with a skinning buffer.
      await testHelper.withViewer(
        (viewer) async {
          final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");
          await viewer.addToScene(cube);

          final renderableManager = FilamentApp.instance!.renderableManager;

          // Locate the renderable child (the skinned mesh).
          ThermionEntity? meshEntity;
          for (final child in await cube.getChildEntities()) {
            if (renderableManager.isRenderable(child)) {
              meshEntity = child;
              break;
            }
          }
          expect(meshEntity, isNotNull, reason: "Expected a renderable child entity for the skinned cube");

          // Sanity check the bone count from the asset matches what we pass.
          final boneNames = await cube.getBoneNames();
          expect(boneNames.length, 1);
          expect(boneNames.first, "MyBone");

          // Identity transform should leave the mesh in its rest pose.
          await renderableManager.setBonesFromMat4(meshEntity!, [Matrix4.identity()]);
          await testHelper.capture(viewer.view, "set_bones_identity");

          // Rotating the single bone 90 degrees should visibly deform the mesh.
          await renderableManager.setBonesFromMat4(meshEntity, [Matrix4.rotationY(pi / 4)]);
          await testHelper.capture(viewer.view, "set_bones_rotated");

          // offset parameter should be accepted (writing past end of buffer is
          // a no-op when boneCount is 1 and only one bone is allocated).
          await renderableManager.setBonesFromMat4(meshEntity, [Matrix4.identity()], offset: 0);

          // Empty list is a safe no-op (short-circuits before FFI call).
          await renderableManager.setBonesFromMat4(meshEntity, <Matrix4>[]);

          expect(renderableManager.isRenderable(meshEntity), true);
        },
        bg: kRed,
        cameraPosition: Vector3(0, 5, 15),
      );
    });

    test('create skinned geometry with two bones', () async {
      await ViewerBuilder(testHelper).setRenderTargetEnabled(true).setBackgroundColor(kGrey).execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Build a skinned quad: bone 0 owns the bottom half (verts 0,1),
        // bone 1 owns the top half (verts 2,3).
        final vertexBuffer =
            await (renderableManager.createVertexBufferBuilder()
                  ..bufferCount(3)
                  ..vertexCount(4)
                  ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
                  ..attribute(VertexAttribute.BONE_INDICES, 1, VertexAttributeType.UBYTE4)
                  ..attribute(VertexAttribute.BONE_WEIGHTS, 2, VertexAttributeType.FLOAT4))
                .build();

        final indexBuffer =
            await (renderableManager.createIndexBufferBuilder()
                  ..indexCount(6)
                  ..bufferType(IndexType.USHORT))
                .build();

        final positions = Float32List.fromList([
          -0.5, -0.5, 0.0, // vertex 0 (bottom-left)
          0.5, -0.5, 0.0, // vertex 1 (bottom-right)
          0.5, 0.5, 0.0, // vertex 2 (top-right)
          -0.5, 0.5, 0.0, // vertex 3 (top-left)
        ]);
        await vertexBuffer.setBufferAt(0, positions);

        final boneIndices = Uint8List.fromList([
          0, 0, 0, 0, // vertex 0: bone 0
          0, 0, 0, 0, // vertex 1: bone 0
          1, 0, 0, 0, // vertex 2: bone 1
          1, 0, 0, 0, // vertex 3: bone 1
        ]);
        await vertexBuffer.setBufferAt(1, boneIndices);

        final boneWeights = Float32List.fromList([
          1.0, 0.0, 0.0, 0.0, // vertex 0: 100% bone 0
          1.0, 0.0, 0.0, 0.0, // vertex 1: 100% bone 0
          1.0, 0.0, 0.0, 0.0, // vertex 2: 100% bone 1
          1.0, 0.0, 0.0, 0.0, // vertex 3: 100% bone 1
        ]);
        await vertexBuffer.setBufferAt(2, boneWeights);

        await indexBuffer.setBuffer(Uint16List.fromList([0, 1, 2, 2, 3, 0]));

        final material = await app.createUnlitMaterialInstance();
        await material.setParameterFloat4("baseColorFactor", 1.0, 0.5, 0.0, 1.0); // Orange

        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(Vector3(-0.5, -0.5, 0.0), Vector3(0.5, 0.5, 0.0)))
          ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, 6)
          ..material(0, material)
          ..skinning(2, [Matrix4.identity(), Matrix4.identity()]);

        final success = await renderableBuilder.build(entity);
        expect(success, true);

        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        final camera = await result.viewer.view.getCamera();
        await camera.lookAt(Vector3(0, 0, 2), focus: Vector3.zero(), up: Vector3(0, 1, 0));

        // Initial pose: both bones identity.
        await testHelper.capture(result.viewer.view, "skinned_initial_pose");

        // Rotate bone 1 (top half) ~45 degrees around Z.
        await renderableManager.setBonesFromMat4(entity, [Matrix4.identity(), Matrix4.rotationZ(0.78)]);
        await testHelper.capture(result.viewer.view, "skinned_after_bone_rotation");

        expect(renderableManager.isRenderable(entity), true);

        // Same update via BoneData (quaternion+translation) path.
        final boneData = [
          BoneData(rotation: Quaternion.identity(), translation: Vector3.zero()),
          BoneData(rotation: Quaternion.axisAngle(Vector3(0, 0, 1), 1.57), translation: Vector3(0.0, 0.5, 0.0)),
        ];
        await renderableManager.setBonesFromBone(entity, boneData);
        await testHelper.capture(result.viewer.view, "skinned_after_bonedata_update");

        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });

    test('morph target operations', () async {
      // Note: This test uses a cube which doesn't have morph targets,
      // but we can test the API returns correct values
      final builder = ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube();

      await builder.execute((result) async {
        final cube = result.assets[0];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Get morph target count (should be 0 for a cube)
        final morphCount = renderableManager.getMorphTargetCount(cube.entity);
        expect(morphCount, equals(0));

        // Try setting morph weights (should handle gracefully with no morph
        // targets)
        await renderableManager.setMorphWeights(cube.entity, [0.5, 0.5], 2);

        await expectLater(renderableManager.setMorphWeights(cube.entity, [0.5], 2), throwsRangeError);
        await expectLater(renderableManager.setMorphWeights(cube.entity, [0.5], -1), throwsRangeError);
        await expectLater(renderableManager.setMorphWeights(cube.entity, [0.5], 1, offset: -1), throwsRangeError);
      });
    });

    test('setMorphWeights updates a morph target on the render thread', () async {
      await testHelper.withViewer((viewer) async {
        final asset = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb", addToScene: true);
        final renderableManager = FilamentApp.instance!.renderableManager;
        final meshEntity = (await asset.getChildEntities()).firstWhere(renderableManager.isRenderable);

        expect(renderableManager.getMorphTargetCount(meshEntity), equals(1));
        await renderableManager.setMorphWeights(meshEntity, [1.0], 1);
        await testHelper.capture(viewer.view, "direct_morph_weight");
      });
    });

    test('full workflow - create, modify, render', () async {
      final builder = ViewerBuilder(testHelper)
          .setRenderTargetEnabled(true)
          .setBackgroundColor(kBlue)
          .setShadowsEnabled(true)
          .addSun(intensity: 50000, castShadows: true, direction: Vector3(1, -1, 0).normalized())
          .addCube(color: kRed, castShadows: true)
          .addPlane(receiveShadows: true);

      await builder.execute((result) async {
        final cube = result.assets[0];
        final plane = result.assets[1];
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Initial capture
        await testHelper.capture(result.viewer.view, "workflow_initial");

        // Modify cube properties
        await renderableManager.setPriority(cube.entity, 7);
        await renderableManager.setVisibilityLayer(cube.entity, 1);
        await renderableManager.setFogEnabled(cube.entity, false);

        // Verify cube is renderable
        expect(renderableManager.isRenderable(cube.entity), true);

        // Modify shadow behavior
        await renderableManager.setCastShadows(cube.entity, false);
        await testHelper.capture(result.viewer.view, "workflow_no_cube_shadow");

        await renderableManager.setCastShadows(cube.entity, true);
        await renderableManager.setReceiveShadows(plane.entity, false);
        await testHelper.capture(result.viewer.view, "workflow_no_plane_shadow");

        // Restore shadows
        await renderableManager.setReceiveShadows(plane.entity, true);
        await testHelper.capture(result.viewer.view, "workflow_final");

        // Verify component counts
        expect(renderableManager.getComponentCount(), greaterThan(0));
        expect(renderableManager.empty(), false);
      });
    });
  });
}
