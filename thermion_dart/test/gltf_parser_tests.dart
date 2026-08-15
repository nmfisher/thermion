import 'dart:io';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gltf_parser");

  setUp(() async {
    await testHelper.setup();
  });

  // CgltfImporter is the facade implementation behind parseGltf; it returns
  // the shared RawMesh type (positions/indices merged across the meshes of
  // the file, strips/fans expanded to triangle lists natively).
  test('parse cube.glb for physics', () async {
    final glbPath = "${testHelper.assetsDir}/cube.glb";
    final buffer = File(glbPath).readAsBytesSync();

    final meshes = CgltfImporter().parse(buffer, formatHint: 'glb');
    expect(meshes.length, 1, reason: "cgltf path returns one merged mesh");
    final mesh = meshes.first;

    // Cube has 8 vertices * 3 components (x,y,z)
    expect(mesh.positions.length, greaterThan(0));
    expect(mesh.positions.length % 3, 0, reason: "Vertices should be in groups of 3 (x,y,z)");

    // Should have indices
    expect(mesh.indices.length, greaterThan(0));
    expect(mesh.indices.length % 3, 0, reason: "Indices should be in groups of 3 (triangles)");

    // Primitive type should be triangles
    expect(mesh.primitiveType, PrimitiveType.TRIANGLES);

    print("Parsed ${mesh.vertexCount} vertices");
    print("Parsed ${mesh.indices.length ~/ 3} triangles");
  });

  test('parse cube.glb and verify vertex bounds', () async {
    final glbPath = "${testHelper.assetsDir}/cube.glb";
    final buffer = File(glbPath).readAsBytesSync();

    final mesh = CgltfImporter().parse(buffer, formatHint: 'glb').first;

    // Find min/max bounds
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    double minZ = double.infinity, maxZ = double.negativeInfinity;

    for (int i = 0; i < mesh.positions.length; i += 3) {
      final x = mesh.positions[i];
      final y = mesh.positions[i + 1];
      final z = mesh.positions[i + 2];

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

  test('parse with non-existent mesh name throws', () async {
    final glbPath = "${testHelper.assetsDir}/cube.glb";
    final buffer = File(glbPath).readAsBytesSync();

    // Try to parse with a mesh name that doesn't exist
    expect(() => CgltfImporter().parse(buffer, meshName: "NonExistentMesh"), throwsException);
  });

  test('verify indices point to valid vertices', () async {
    final glbPath = "${testHelper.assetsDir}/cube.glb";
    final buffer = File(glbPath).readAsBytesSync();

    final mesh = CgltfImporter().parse(buffer, formatHint: 'glb').first;

    final vertexCount = mesh.vertexCount;

    // All indices should be within valid range
    for (final index in mesh.indices) {
      expect(index, lessThan(vertexCount), reason: "Index $index out of bounds (vertex count: $vertexCount)");
    }
  });
}
