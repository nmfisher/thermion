import 'dart:io';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/interface/gltf_mesh_data.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_gltf_mesh_data.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gltf_parser");

  setUp(() async {
    await testHelper.setup();
  });

  group('glTF to instanced renderable', () {
    test('parse cube.glb and create instanced renderable', () async {
      await ViewerBuilder(testHelper)
          .setBackgroundColor(kWhite)
          .setCameraPosition(Vector3(5, 5, 5))
          .execute((result) async {
        final app = FilamentApp.instance!;
        final renderableManager = app.renderableManager;

        // Parse the glb file to get geometry data
        final glbPath = "${testHelper.testDir}/assets/cube.glb";
        final buffer = File(glbPath).readAsBytesSync();
        final meshData = await FFIGltfMeshData.parse(buffer);

        // Verify parsed data
        expect(meshData.vertices.length, greaterThan(0));
        expect(meshData.indices, isNotNull);
        expect(meshData.indices!.length, greaterThan(0));

        final vertexCount = meshData.vertices.length ~/ 3;
        final indexCount = meshData.indices!.length;

        print("Creating instanced renderable with $vertexCount vertices, $indexCount indices");

        // Create vertex buffer with positions from parsed glTF
        final vertexBuffer = await (renderableManager.createVertexBufferBuilder()
              ..bufferCount(1)
              ..vertexCount(vertexCount)
              ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3))
            .build();

        // Create index buffer
        final indexBuffer = await (renderableManager.createIndexBufferBuilder()
              ..indexCount(indexCount)
              ..bufferType(IndexType.UINT))
            .build();

        // Upload vertex data from parsed glTF
        await vertexBuffer.setBufferAt(0, meshData.vertices);

        // Upload index data from parsed glTF
        await indexBuffer.setBuffer(meshData.indices!);

        // Calculate bounding box from vertices
        double minX = double.infinity, maxX = double.negativeInfinity;
        double minY = double.infinity, maxY = double.negativeInfinity;
        double minZ = double.infinity, maxZ = double.negativeInfinity;

        for (int i = 0; i < meshData.vertices.length; i += 3) {
          final x = meshData.vertices[i];
          final y = meshData.vertices[i + 1];
          final z = meshData.vertices[i + 2];
          minX = x < minX ? x : minX;
          maxX = x > maxX ? x : maxX;
          minY = y < minY ? y : minY;
          maxY = y > maxY ? y : maxY;
          minZ = z < minZ ? z : minZ;
          maxZ = z > maxZ ? z : maxZ;
        }

        // Create material
        final material = await testHelper.loadSolidColorMaterial(
            r: 1.0, g: 0.5, b: 0.0); // Orange

        // Create entity and renderable with multiple instances
        final entity = await app.createEntity();
        final renderableBuilder = renderableManager.createBuilder(1)
          ..boundingBox(Aabb3.minMax(
              Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ)))
          ..geometry(0, meshData.primitiveType, vertexBuffer, indexBuffer, 0, indexCount)
          ..material(0, material)
          ..culling(false)
          ..instances(5); // Create 5 instances of the cube

        final success = await renderableBuilder.build(entity);
        expect(success, true, reason: "Failed to build instanced renderable");

        final scene = await result.viewer.view.getScene();
        await scene.addEntity(entity);

        await testHelper.capture(result.viewer.view, "cube_glb_5_instances");

        print("Successfully created instanced renderable with 5 instances from parsed cube.glb");

        // Cleanup
        await vertexBuffer.destroy();
        await indexBuffer.destroy();
      });
    });
  });

  group('glTF Parser', () {
    test('parse cube.glb for physics', () async {
      final glbPath = "${testHelper.testDir}/assets/cube.glb";
      final buffer = File(glbPath).readAsBytesSync();

      final meshData = await FFIGltfMeshData.parse(buffer);

      // Cube has 8 vertices * 3 components (x,y,z)
      expect(meshData.vertices.length, greaterThan(0));
      expect(meshData.vertices.length % 3, 0,
          reason: "Vertices should be in groups of 3 (x,y,z)");

      // Should have indices
      expect(meshData.indices, isNotNull);
      expect(meshData.indices!.length, greaterThan(0));
      expect(meshData.indices!.length % 3, 0,
          reason: "Indices should be in groups of 3 (triangles)");

      // Primitive type should be triangles
      expect(meshData.primitiveType, PrimitiveType.TRIANGLES);

      print("Parsed ${meshData.vertices.length ~/ 3} vertices");
      print("Parsed ${meshData.indices!.length ~/ 3} triangles");
    });

    test('parse cube.glb and verify vertex bounds', () async {
      final glbPath = "${testHelper.testDir}/assets/cube.glb";
      final buffer = File(glbPath).readAsBytesSync();

      final meshData = await FFIGltfMeshData.parse(buffer);

      // Find min/max bounds
      double minX = double.infinity, maxX = double.negativeInfinity;
      double minY = double.infinity, maxY = double.negativeInfinity;
      double minZ = double.infinity, maxZ = double.negativeInfinity;

      for (int i = 0; i < meshData.vertices.length; i += 3) {
        final x = meshData.vertices[i];
        final y = meshData.vertices[i + 1];
        final z = meshData.vertices[i + 2];

        minX = x < minX ? x : minX;
        maxX = x > maxX ? x : maxX;
        minY = y < minY ? y : minY;
        maxY = y > maxY ? y : maxY;
        minZ = z < minZ ? z : minZ;
        maxZ = z > maxZ ? z : maxZ;
      }

      print("Bounds: X[$minX, $maxX] Y[$minY, $maxY] Z[$minZ, $maxZ]");

      // Cube should have reasonable bounds
      expect(maxX - minX, greaterThan(0));
      expect(maxY - minY, greaterThan(0));
      expect(maxZ - minZ, greaterThan(0));
    });

    test('parse with non-existent mesh name returns empty or null', () async {
      final glbPath = "${testHelper.testDir}/assets/cube.glb";
      final buffer = File(glbPath).readAsBytesSync();

      // Try to parse with a mesh name that doesn't exist
      expect(
        () async =>
            await FFIGltfMeshData.parse(buffer, meshName: "NonExistentMesh"),
        throwsException,
      );
    });

    test('verify indices point to valid vertices', () async {
      final glbPath = "${testHelper.testDir}/assets/cube.glb";
      final buffer = File(glbPath).readAsBytesSync();

      final meshData = await FFIGltfMeshData.parse(buffer);

      final vertexCount = meshData.vertices.length ~/ 3;

      // All indices should be within valid range
      for (final index in meshData.indices!) {
        expect(index, lessThan(vertexCount),
            reason: "Index $index out of bounds (vertex count: $vertexCount)");
      }
    });
  });
}
