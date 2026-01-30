import 'dart:io';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("wireframe_renderable");
  await testHelper.setup();

  test('create wireframe renderable from cube geometry', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .execute((result) async {
      // Load the wireframe material
      final wireframeMaterial = await testHelper.loadWireframeMaterial(
        edgeR: 1.0,
        edgeG: 1.0,
        edgeB: 1.0,
        edgeA: 1.0,
        faceR: 0.2,
        faceG: 0.2,
        faceB: 0.2,
        faceA: 0.3,
        edgeWidth: 1.5,
      );

      // Create cube geometry
      final cubeGeometry = GeometryHelper.cube();

      // Create wireframe renderable from geometry
      final wireframeRenderable = await WireframeRenderable.createFromGeometry(
        viewer: result.viewer,
        geometry: cubeGeometry,
        wireframeMaterial: wireframeMaterial,
        initiallyWireframe: false,
      );

      // Verify initial state is solid
      expect(wireframeRenderable.isWireframeVisible, isFalse);
      expect(wireframeRenderable.solidAsset, isNotNull);
      expect(wireframeRenderable.wireframeEntity, isNotNull);

      // Capture solid view
      await testHelper.capture(result.viewer.view, "wireframe_renderable_solid");

      // Clean up
      await wireframeRenderable.dispose();
    });
  });

  test('toggle between solid and wireframe modes', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .execute((result) async {
      final wireframeMaterial = await testHelper.loadWireframeMaterial(
        edgeR: 0.0,
        edgeG: 1.0,
        edgeB: 0.0,
        edgeA: 1.0,
        faceR: 0.0,
        faceG: 0.0,
        faceB: 0.0,
        faceA: 0.0,
        edgeWidth: 1.0,
      );

      // Single triangle - absolute basics
      final vertices = Float32List.fromList([
        0.0, 1.0, 0.0,   // vertex 0: top
        -1.0, -1.0, 0.0, // vertex 1: bottom-left
        1.0, -1.0, 0.0,  // vertex 2: bottom-right
      ]);

      final indices = Int32List.fromList([0, 1, 2]);

      final cubeGeometry = Geometry(
        vertices,
        indices,
        primitiveType: PrimitiveType.TRIANGLES,
        indexType: IndexType.UINT,
      );

      final wireframeRenderable = await WireframeRenderable.createFromGeometry(
        viewer: result.viewer,
        geometry: cubeGeometry,
        wireframeMaterial: wireframeMaterial,
        initiallyWireframe: false,
      );

      // Initially solid
      expect(wireframeRenderable.isWireframeVisible, isFalse);
      await testHelper.capture(result.viewer.view, "toggle_test_solid");

      // Switch to wireframe
      await wireframeRenderable.showWireframe();
      expect(wireframeRenderable.isWireframeVisible, isTrue);
      await testHelper.capture(result.viewer.view, "toggle_test_wireframe");

      // Switch back to solid
      await wireframeRenderable.showSolid();
      expect(wireframeRenderable.isWireframeVisible, isFalse);
      await testHelper.capture(result.viewer.view, "toggle_test_solid_again");

      // Test toggle()
      await wireframeRenderable.toggle();
      expect(wireframeRenderable.isWireframeVisible, isTrue);

      await wireframeRenderable.toggle();
      expect(wireframeRenderable.isWireframeVisible, isFalse);

      await wireframeRenderable.dispose();
    });
  });

  test('initially wireframe mode', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .execute((result) async {
      final wireframeMaterial = await testHelper.loadWireframeMaterial(
        edgeR: 1.0,
        edgeG: 0.0,
        edgeB: 0.0,
        edgeA: 1.0,
        edgeWidth: 3.0,
      );

      final cubeGeometry = GeometryHelper.cube();

      final wireframeRenderable = await WireframeRenderable.createFromGeometry(
        viewer: result.viewer,
        geometry: cubeGeometry,
        wireframeMaterial: wireframeMaterial,
        initiallyWireframe: true,
      );

      // Should start in wireframe mode
      expect(wireframeRenderable.isWireframeVisible, isTrue);
      await testHelper.capture(
          result.viewer.view, "initially_wireframe");

      await wireframeRenderable.dispose();
    });
  });

  test('setTransform applies to both solid and wireframe', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .execute((result) async {
      final wireframeMaterial = await testHelper.loadWireframeMaterial();

      final cubeGeometry = GeometryHelper.cube();

      final wireframeRenderable = await WireframeRenderable.createFromGeometry(
        viewer: result.viewer,
        geometry: cubeGeometry,
        wireframeMaterial: wireframeMaterial,
      );

      // Apply transform
      final transform = Matrix4.identity()
        ..translateByVector3(Vector3(2.0, 0.0, 0.0))
        ..scaleByVector3(Vector3(0.5, 0.5, 0.5));
      await wireframeRenderable.setTransform(transform);

      // Capture solid with transform
      await testHelper.capture(result.viewer.view, "transform_solid");

      // Switch to wireframe and verify transform still applies
      await wireframeRenderable.showWireframe();
      await testHelper.capture(result.viewer.view, "transform_wireframe");

      // Get world transform
      final worldTransform = await wireframeRenderable.getWorldTransform();
      expect(worldTransform, isNotNull);

      await wireframeRenderable.dispose();
    });
  });

  test('activeEntity returns correct entity based on mode', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .execute((result) async {
      final wireframeMaterial = await testHelper.loadWireframeMaterial();

      final cubeGeometry = GeometryHelper.cube();

      final wireframeRenderable = await WireframeRenderable.createFromGeometry(
        viewer: result.viewer,
        geometry: cubeGeometry,
        wireframeMaterial: wireframeMaterial,
      );

      final solidEntity = wireframeRenderable.solidAsset!.entity;
      final wireframeEntity = wireframeRenderable.wireframeEntity!;

      // In solid mode, activeEntity should be solid
      expect(wireframeRenderable.activeEntity, equals(solidEntity));

      // In wireframe mode, activeEntity should be wireframe
      await wireframeRenderable.showWireframe();
      expect(wireframeRenderable.activeEntity, equals(wireframeEntity));

      await wireframeRenderable.dispose();
    });
  });

  test('dispose cleans up both entities', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .execute((result) async {
      final wireframeMaterial = await testHelper.loadWireframeMaterial();

      final cubeGeometry = GeometryHelper.cube();

      final wireframeRenderable = await WireframeRenderable.createFromGeometry(
        viewer: result.viewer,
        geometry: cubeGeometry,
        wireframeMaterial: wireframeMaterial,
      );

      // Dispose
      await wireframeRenderable.dispose();

      // Verify entities are null after disposal
      expect(wireframeRenderable.solidAsset, isNull);
      expect(wireframeRenderable.wireframeEntity, isNull);

      // Calling dispose again should be safe (no-op)
      await wireframeRenderable.dispose();
    });
  });

  test('throws StateError after disposal', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .execute((result) async {
      final wireframeMaterial = await testHelper.loadWireframeMaterial();

      final cubeGeometry = GeometryHelper.cube();

      final wireframeRenderable = await WireframeRenderable.createFromGeometry(
        viewer: result.viewer,
        geometry: cubeGeometry,
        wireframeMaterial: wireframeMaterial,
      );

      await wireframeRenderable.dispose();

      // All methods should throw after disposal
      expect(() => wireframeRenderable.activeEntity, throwsStateError);
      expect(() async => await wireframeRenderable.showWireframe(),
          throwsStateError);
      expect(
          () async => await wireframeRenderable.showSolid(), throwsStateError);
      expect(() async => await wireframeRenderable.toggle(), throwsStateError);
      expect(
          () async =>
              await wireframeRenderable.setTransform(Matrix4.identity()),
          throwsStateError);
    });
  });

  test('create wireframe from glTF file', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .execute((result) async {
      final wireframeMaterial = await testHelper.loadWireframeMaterial(
        edgeR: 0.0,
        edgeG: 1.0,
        edgeB: 0.0,
        edgeA: 1.0,
        faceR: 0.1,
        faceG: 0.1,
        faceB: 0.1,
        faceA: 0.5,
        edgeWidth: 2.0,
      );

      // Load glTF file from examples/assets
      final gltfData = await File(
        '${testHelper.testDir}/../../examples/assets/cube.glb',
      ).readAsBytes();

      final wireframeRenderable = await WireframeRenderable.create(
        viewer: result.viewer,
        gltfData: gltfData,
        wireframeMaterial: wireframeMaterial,
        initiallyWireframe: false,
      );

      // Initially solid
      expect(wireframeRenderable.isWireframeVisible, isFalse);
      await testHelper.capture(result.viewer.view, "gltf_solid");

      // Switch to wireframe
      await wireframeRenderable.showWireframe();
      expect(wireframeRenderable.isWireframeVisible, isTrue);
      await testHelper.capture(result.viewer.view, "gltf_wireframe");

      await wireframeRenderable.dispose();
    });
  });
}
