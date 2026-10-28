import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/grid_overlay.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("overlay");
  await testHelper.setup();

  test('toggle grid visibility', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setGridOverlayVisibility(true);
      await testHelper.capture(viewer.view, "grid_visible");
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(0, 5, 10));
      await testHelper.capture(viewer.view, "grid_visible_angle");
      for (int i = 0; i < 10; i++) {
        await camera.lookAt(Vector3(0, 1 + (i * 10), 0.005), focus: Vector3.zero());
        await testHelper.capture(viewer.view, "grid_visible_fade${i}");
      }
      await viewer.setGridOverlayVisibility(false);
      await testHelper.capture(viewer.view, "grid_hidden");
    }, postProcessing: true);
  });

  test('grid with custom spacing', () async {
    await testHelper.withViewer((viewer) async {
      // Test with tighter spacing
      await viewer.setGridOverlayVisibility(true, spacing: [0.5, 2.0, 10.0]);
      await testHelper.capture(viewer.view, "grid_custom_spacing");
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(0, 5, 10));
      await testHelper.capture(viewer.view, "grid_custom_spacing_angle");
    }, postProcessing: true);
  });

  test('grid with custom fade parameters', () async {
    await testHelper.withViewer((viewer) async {
      // Test with adjusted fade ranges for a smaller scene
      await viewer.setGridOverlayVisibility(
        true,
        spacing: [0.5, 2.0, 10.0],
        fadeInStart: [0.001, 1.0, 5.0],
        fadeInEnd: [0.001, 10.0, 50.0],
        fadeOutStart: [2.0, 50.0, 500.0],
        fadeOutEnd: [20.0, 200.0, 2000.0],
      );
      await testHelper.capture(viewer.view, "grid_custom_fade");
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(0, 5, 10));
      await testHelper.capture(viewer.view, "grid_custom_fade_angle");

      // Test fade behavior by moving camera away
      await camera.lookAt(Vector3(0, 100, 0.005), focus: Vector3.zero());
      await testHelper.capture(viewer.view, "grid_custom_fade_distant");
    }, postProcessing: true);
  });

  test('grid rendering does not depend on entity allocation', () async {
    await testHelper.withViewer((viewer) async {
      final app = FilamentApp.instance!;
      final ffiViewer = viewer as ThermionViewerFFI;
      await viewer.setGridOverlayVisibility(true);
      final expected = (await testHelper.capture(viewer.view, null)).values.single;
      final expectedPixels = Float32List.view(expected.buffer, expected.offsetInBytes);

      // Filament reuses entity IDs after enough entities have been freed.
      // Reach that point at different stages of grid creation.
      for (final count in [1024, 1025, 1026, 1030]) {
        await ffiViewer.removeGridOverlay(destroy: true);
        final unusedEntities = <ThermionEntity>[];
        for (var i = 0; i < count; i++) {
          unusedEntities.add(await app.createEntity(createTransformComponent: false));
        }
        for (final entity in unusedEntities) {
          await app.destroyEntity(entity);
        }
        await app.render();
        await app.flush();
        await viewer.setGridOverlayVisibility(true);
        final actual = (await testHelper.capture(viewer.view, null)).values.single;
        final actualPixels = Float32List.view(actual.buffer, actual.offsetInBytes);
        var signal = 0.0;
        var difference = 0.0;
        for (var i = 0; i < expectedPixels.length; i++) {
          if (i % 4 == 3) continue;
          signal += expectedPixels[i].abs();
          difference += (expectedPixels[i] - actualPixels[i]).abs();
        }
        expect(signal, greaterThan(0));
        expect(difference / signal, lessThan(0.00001), reason: 'Grid changed after allocating $count unused entities');
      }
      await ffiViewer.removeGridOverlay(destroy: true);
    });
  });

  test('transparent grid levels do not hide other levels', () async {
    final app = FilamentApp.instance! as FFIFilamentApp;
    final (viewer, swapChain) = await testHelper.createViewer();
    try {
      await viewer.setGridOverlayVisibility(true);
      final grid = await GridOverlay.create(app);
      final entities = grid.entities;

      // The same grid color blends identically in either order without axes.
      for (final entity in entities) {
        final material = (await app.renderableManager.getMaterialInstanceAt(entity, 0))!;
        await material.setParameterBool('showAxisX', false);
        await material.setParameterBool('showAxisZ', false);
      }
      for (var i = 0; i < entities.length; i++) {
        await app.renderableManager.setPriority(entities[i], i);
      }
      final forward = (await testHelper.capture(viewer.view, null)).values.single;
      final forwardPixels = Float32List.fromList(Float32List.view(forward.buffer, forward.offsetInBytes));

      // Transparent large levels must not hide the smaller visible levels.
      for (var i = 0; i < entities.length; i++) {
        await app.renderableManager.setPriority(entities[i], entities.length - i);
      }
      final reverse = (await testHelper.capture(viewer.view, null)).values.single;
      final reversePixels = Float32List.view(reverse.buffer, reverse.offsetInBytes);
      var signal = 0.0;
      var difference = 0.0;
      for (var i = 0; i < forwardPixels.length; i++) {
        if (i % 4 == 3) continue;
        signal += forwardPixels[i].abs();
        difference += (forwardPixels[i] - reversePixels[i]).abs();
      }
      expect(signal, greaterThan(0));
      expect(difference / signal, lessThan(0.01));
    } finally {
      await viewer.dispose();
      await testHelper.disposeColorGradings();
      await FilamentApp.instance!.destroySwapChain(swapChain);
    }
  });

  test('grid remains occluded by opaque scene geometry', () async {
    final app = FilamentApp.instance! as FFIFilamentApp;
    final (viewer, swapChain) = await testHelper.createViewer();
    MaterialInstance? material;
    try {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(0, 5, 0.005), focus: Vector3.zero());
      await viewer.setGridOverlayVisibility(false);
      final grid = await GridOverlay.create(app);
      final gridMaterials = <MaterialInstance>[];
      for (final entity in grid.entities) {
        gridMaterials.add((await app.renderableManager.getMaterialInstanceAt(entity, 0))!);
      }
      material = await app.createUnlitMaterialInstance();
      await material.setParameterFloat4('baseColorFactor', 0, 1, 0, 1);
      final cube = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [material],
      );
      await cube.setTransform(Matrix4.diagonal3Values(0.5, 0.5, 0.5)..setTranslation(Vector3(0, 1, 0)));

      final viewport = await viewer.view.getViewport();
      final center = ((viewport.height ~/ 2) * viewport.width + viewport.width ~/ 2) * 4;
      final plain = (await testHelper.capture(viewer.view, null)).values.single;
      final plainPixels = Float32List.view(plain.buffer, plain.offsetInBytes);
      final expected = plainPixels.sublist(center, center + 3);
      expect(expected[1], greaterThan(0.5), reason: 'The center pixel must be inside the green cube.');

      await viewer.setGridOverlayVisibility(true);
      final occluded = (await testHelper.capture(viewer.view, null)).values.single;
      final occludedPixels = Float32List.view(occluded.buffer, occluded.offsetInBytes);
      expect(occludedPixels.sublist(center, center + 3), orderedEquals(expected));

      // Prove that the grid covers this pixel when depth testing is disabled.
      for (final gridMaterial in gridMaterials) {
        await gridMaterial.setDepthCullingEnabled(false);
      }
      final overlaid = (await testHelper.capture(viewer.view, null)).values.single;
      final overlaidPixels = Float32List.view(overlaid.buffer, overlaid.offsetInBytes);
      var difference = 0.0;
      for (var channel = 0; channel < 3; channel++) {
        difference += (overlaidPixels[center + channel] - expected[channel]).abs();
      }
      expect(difference, greaterThan(0.01));
    } finally {
      await viewer.dispose();
      await material?.destroy();
      await testHelper.disposeColorGradings();
      await FilamentApp.instance!.destroySwapChain(swapChain);
    }
  });

  test('translation axis X', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(10, 10, 10), focus: Vector3.zero());

      await viewer.setTranslationAxisVisibility(
        true,
        origin: Vector3.zero(),
        axis: Axis.X,
        lineWidth: 5.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_x");
    }, postProcessing: true);
  });

  test('translation axis Y', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(10, 10, 10), focus: Vector3.zero());

      await viewer.setTranslationAxisVisibility(
        true,
        origin: Vector3.zero(),
        axis: Axis.Y,
        lineWidth: 5.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_y");
    }, postProcessing: true);
  });

  test('translation axis Z', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(10, 10, 10), focus: Vector3.zero());

      await viewer.setTranslationAxisVisibility(
        true,
        origin: Vector3.zero(),
        axis: Axis.Z,
        lineWidth: 5.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_z");
    }, postProcessing: true);
  });

  test('translation axis at offset origin', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(20, 10, 20), focus: Vector3(10, 0, 10));

      await viewer.setTranslationAxisVisibility(
        true,
        origin: Vector3(10, 0, 10),
        axis: Axis.X,
        lineWidth: 5.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_offset_origin");
    }, postProcessing: true);
  });

  test('translation axis from entity position', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(10, 15, 10), focus: Vector3(0, 10, 0));

      // Create a cube and position it at (0, 10, 0)
      final cube = await viewer.createGeometry(GeometryUtils.cube());
      await FilamentApp.instance!.setTransform(cube.entity, Matrix4.translation(Vector3(0, 10, 0)));
      await viewer.addToScene(cube);

      // Show translation axis X using entity parameter (should be at cube's position)
      // lineWidth is now in screen-space pixels
      await viewer.setTranslationAxisVisibility(
        true,
        entity: cube.entity,
        axis: Axis.X,
        lineWidth: 1.0, // 1px screen-space
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_from_entity_x_pos1");

      // Change to Y axis at same position
      await viewer.setTranslationAxisVisibility(
        true,
        entity: cube.entity,
        axis: Axis.Y,
        lineWidth: 1.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_from_entity_y_pos1");

      // Change to Z axis at same position
      await viewer.setTranslationAxisVisibility(
        true,
        entity: cube.entity,
        axis: Axis.Z,
        lineWidth: 1.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_from_entity_z_pos1");

      // Move cube to a different position (-5, 5, 8)
      await FilamentApp.instance!.setTransform(cube.entity, Matrix4.translation(Vector3(-5, 5, 8)));
      await camera.lookAt(Vector3(5, 10, 18), focus: Vector3(-5, 5, 8));

      // Show X axis at new position
      await viewer.setTranslationAxisVisibility(
        true,
        entity: cube.entity,
        axis: Axis.X,
        lineWidth: 1.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_from_entity_x_pos2");

      // Show Y axis at new position (critical test for the fix)
      await viewer.setTranslationAxisVisibility(
        true,
        entity: cube.entity,
        axis: Axis.Y,
        lineWidth: 1.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_from_entity_y_pos2");

      // Show Z axis at new position
      await viewer.setTranslationAxisVisibility(
        true,
        entity: cube.entity,
        axis: Axis.Z,
        lineWidth: 1.0,
        lineLength: 50.0,
      );
      await testHelper.capture(viewer.view, "translation_axis_from_entity_z_pos2");

      await viewer.removeFromScene(cube);
    }, postProcessing: true);
  });

  test('translation axis visibility toggle', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(10, 10, 10), focus: Vector3.zero());

      // Show X axis
      await viewer.setTranslationAxisVisibility(true, origin: Vector3.zero(), axis: Axis.X, lineWidth: 5.0);
      await testHelper.capture(viewer.view, "translation_axis_show");

      // Hide
      await viewer.setTranslationAxisVisibility(false);
      await testHelper.capture(viewer.view, "translation_axis_hide");

      // Show Y axis (switching axes)
      await viewer.setTranslationAxisVisibility(true, origin: Vector3.zero(), axis: Axis.Y, lineWidth: 5.0);
      await testHelper.capture(viewer.view, "translation_axis_switch_to_y");

      // Show Z axis (switching axes again)
      await viewer.setTranslationAxisVisibility(true, origin: Vector3.zero(), axis: Axis.Z, lineWidth: 5.0);
      await testHelper.capture(viewer.view, "translation_axis_switch_to_z");
    }, postProcessing: true);
  });

  test('highlighting requires accessible buffers while flat shading requires unwelded geometry', () async {
    await testHelper.withViewer((viewer) async {
      final accessibleGeometryMatcher = throwsA(
        isA<StateError>().having((e) => e.toString(), 'message', contains('requires accessible geometry buffers')),
      );
      final unweldedMatcher = throwsA(
        isA<StateError>().having(
          (e) => e.toString(),
          'message',
          contains('requiredGeometryCapabilities containing uniqueTriangleCorners'),
        ),
      );

      final original = await viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb", addToScene: true);
      await expectLater(viewer.view.setStencilHighlight(original), accessibleGeometryMatcher);
      await expectLater(original.setFlatShading(true), unweldedMatcher);

      await expectLater(
        viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          requiredGeometryCapabilities: const {
            SceneAssetGeometryCapability.preservedTopology,
            SceneAssetGeometryCapability.uniqueTriangleCorners,
          },
        ),
        throwsArgumentError,
      );

      // Editable assets preserve reusable vertex/index buffers, so the
      // POSITION-only silhouette pass works without barycentrics. They still
      // cannot swap the tangent BufferObjects required by flat shading.
      final editable = await viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.accessibleGeometryBuffers},
        addToScene: true,
      );
      expect(editable.getVertexBuffer(), isNotNull);
      expect(editable.getVertexBuffer()!.supportsSetBufferAt, isTrue);
      expect(editable.geometryCapabilities, contains(SceneAssetGeometryCapability.accessibleGeometryBuffers));
      expect(editable.geometryCapabilities, contains(SceneAssetGeometryCapability.writableVertices));
      expect(editable.geometryCapabilities, contains(SceneAssetGeometryCapability.preservedTopology));
      await viewer.view.setStencilHighlight(editable);
      await viewer.view.removeStencilHighlight(editable);
      await expectLater(editable.setFlatShading(true), unweldedMatcher);
    });
  });
}
