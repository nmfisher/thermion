import 'dart:io';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_gltf_mesh_data.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gltf_parser");

  setUp(() async {
    await testHelper.setup();
  });

  test('parse cube.glb for physics', () async {
    final glbPath = "${testHelper.assetsDir}/cube.glb";
    final buffer = File(glbPath).readAsBytesSync();

    final meshData = await FFIGltfMeshData.parse(buffer);

    // Cube has 8 vertices * 3 components (x,y,z)
    expect(meshData.vertices.length, greaterThan(0));
    expect(meshData.vertices.length % 3, 0, reason: "Vertices should be in groups of 3 (x,y,z)");

    // Should have indices
    expect(meshData.indices, isNotNull);
    expect(meshData.indices!.length, greaterThan(0));
    expect(meshData.indices!.length % 3, 0, reason: "Indices should be in groups of 3 (triangles)");

    // Primitive type should be triangles
    expect(meshData.primitiveType, PrimitiveType.TRIANGLES);

    print("Parsed ${meshData.vertices.length ~/ 3} vertices");
    print("Parsed ${meshData.indices!.length ~/ 3} triangles");
  });

  test('parse cube.glb and verify vertex bounds', () async {
    final glbPath = "${testHelper.assetsDir}/cube.glb";
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
    final glbPath = "${testHelper.assetsDir}/cube.glb";
    final buffer = File(glbPath).readAsBytesSync();

    // Try to parse with a mesh name that doesn't exist
    expect(() async => await FFIGltfMeshData.parse(buffer, meshName: "NonExistentMesh"), throwsException);
  });

  test('verify indices point to valid vertices', () async {
    final glbPath = "${testHelper.assetsDir}/cube.glb";
    final buffer = File(glbPath).readAsBytesSync();

    final meshData = await FFIGltfMeshData.parse(buffer);

    final vertexCount = meshData.vertices.length ~/ 3;

    // All indices should be within valid range
    for (final index in meshData.indices!) {
      expect(index, lessThan(vertexCount), reason: "Index $index out of bounds (vertex count: $vertexCount)");
    }
  });
}
