import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
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

  test('setStencilHighlight and setFlatShading throw without unwelded vertex buffers', () async {
    await testHelper.withViewer((viewer) async {
      Future<void> expectUnweldedOperationsToThrow(ThermionAsset cube) async {
        final matcher = throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('vertexBufferMode: VertexBufferMode.unwelded'),
          ),
        );
        await expectLater(viewer.view.setStencilHighlight(cube), matcher);
        await expectLater(cube.setFlatShading(true), matcher);
      }

      final original = await viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb", addToScene: true);
      await expectUnweldedOperationsToThrow(original);

      // Editable assets have preserved geometry too, but no barycentric data
      // or swappable tangent BufferObjects. They must not pass a mere
      // getVertexBuffer() != null check.
      final editable = await viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        vertexBufferMode: VertexBufferMode.editable,
        addToScene: true,
      );
      expect(editable.getVertexBuffer(), isNotNull);
      await expectUnweldedOperationsToThrow(editable);
    });
  });
}
