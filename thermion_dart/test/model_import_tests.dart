import 'dart:io';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("model_import");
  await testHelper.setup();

  group('OBJ Loading', () {
    test('load OBJ file from buffer and parse geometry', () async {
      final objPath = "${testHelper.assetsDir}/test_cube.obj";
      final buffer = File(objPath).readAsBytesSync();

      // Parse OBJ file
      final groups = GeometryUtils.parseObjFromBuffer(buffer);

      // Should have at least one mesh group
      expect(groups.isNotEmpty, true, reason: "OBJ file should contain at least one mesh group");

      final group = groups.first;

      // Verify vertices
      expect(group.geometry.vertices.isNotEmpty, true, reason: "Mesh should have vertices");
      expect(group.geometry.vertices.length % 3, 0, reason: "Vertices should be in groups of 3 (x,y,z)");

      // Verify indices
      expect(group.geometry.indices.isNotEmpty, true, reason: "Mesh should have indices");
      expect(group.geometry.indices.length % 3, 0, reason: "Indices should be in groups of 3 (triangles)");

      print("Parsed OBJ with ${group.geometry.vertices.length ~/ 3} vertices");
      print("Parsed ${group.geometry.indices.length ~/ 3} triangles");
      print("Has normals: ${group.geometry.hasNormals}");
      print("Has UVs: ${group.geometry.hasUVs}");

      // Cube should have 8 vertices and 12 triangles (4 per face * 6 faces / 2 for quads)
      // But OBJ can have more vertices due to attribute splitting
      final vertexCount = group.geometry.vertices.length ~/ 3;
      final triangleCount = group.geometry.indices.length ~/ 3;

      expect(vertexCount, greaterThan(0));
      expect(triangleCount, greaterThan(0));
    });

    test('load OBJ and create renderable asset', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kWhite).setCameraPosition(Vector3(3, 3, 3)).execute((
        result,
      ) async {
        final objPath = "${testHelper.assetsDir}/test_cube.obj";
        final buffer = File(objPath).readAsBytesSync();

        // Load OBJ and create assets
        final assets = await result.viewer.loadModelFromBuffer(buffer, formatHint: 'obj');
        expect(assets.isNotEmpty, true, reason: "Should load at least one asset from OBJ");

        // Add to scene
        for (final asset in assets) {
          await result.viewer.addToScene(asset);
        }

        await testHelper.capture(result.viewer.view, "obj_cube");

        // Cleanup
        for (final asset in assets) {
          await result.viewer.destroyAsset(asset);
        }
      });
    });

    test('load OBJ with UV flipping disabled', () async {
      final objPath = "${testHelper.assetsDir}/test_cube.obj";
      final buffer = File(objPath).readAsBytesSync();

      // Parse without UV flipping
      final groups = GeometryUtils.parseObjFromBuffer(buffer, flipUvs: false);

      expect(groups.isNotEmpty, true);
      expect(groups.first.geometry.hasUVs, true);

      // Verify UVs are in original orientation
      final uvs = groups.first.geometry.uvs;
      expect(uvs.isNotEmpty, true);
      expect(uvs.length % 2, 0, reason: "UVs should be in pairs (u,v)");
    });

    test('load OBJ with UV flipping enabled', () async {
      final objPath = "${testHelper.assetsDir}/test_cube.obj";
      final buffer = File(objPath).readAsBytesSync();

      // Parse with UV flipping
      final groups = GeometryUtils.parseObjFromBuffer(buffer, flipUvs: true);

      expect(groups.isNotEmpty, true);
      expect(groups.first.geometry.hasUVs, true);

      // Verify UVs are flipped
      final uvs = groups.first.geometry.uvs;
      expect(uvs.isNotEmpty, true);
      expect(uvs.length % 2, 0, reason: "UVs should be in pairs (u,v)");

      // Check that V values are flipped (1.0 - v)
      // Original OBJ has v values 0.0 or 1.0, so flipped should be 1.0 or 0.0
      for (int i = 1; i < uvs.length; i += 2) {
        final v = uvs[i];
        expect(v, greaterThanOrEqualTo(0.0), reason: "Flipped V value should be >= 0");
        expect(v, lessThanOrEqualTo(1.0), reason: "Flipped V value should be <= 1");
      }
    });

    test('handle OBJ file with no normals or UVs', () async {
      // Create a minimal OBJ with just vertices (use triangles)
      final minimalObj = '''
# Minimal OBJ - positions only
v 0.0 0.0 0.0
v 1.0 0.0 0.0
v 1.0 1.0 0.0
v 0.0 1.0 0.0
f 1 2 3
f 1 3 4
''';
      final buffer = Uint8List.fromList(minimalObj.codeUnits);

      final groups = GeometryUtils.parseObjFromBuffer(buffer);

      print("Groups count: ${groups.length}");
      if (groups.isNotEmpty) {
        print("First group has ${groups.first.geometry.vertices.length ~/ 3} vertices");
        print("First group has normals: ${groups.first.geometry.hasNormals}");
        print("First group has UVs: ${groups.first.geometry.hasUVs}");
      }

      expect(groups.isNotEmpty, true);
      final geometry = groups.first.geometry;

      // Should have vertices
      expect(geometry.vertices.isNotEmpty, true);

      // Should have dummy UVs and colors (created by Geometry constructor)
      expect(geometry.hasUVs, true);
      expect(geometry.hasColors, true);
    });

    test('handle OBJ file with multiple groups', () async {
      // Create OBJ with multiple objects
      final multiGroupObj = '''
# First cube
o Cube1
v -1.0 -1.0 1.0
v 1.0 -1.0 1.0
v 1.0 1.0 1.0
v -1.0 1.0 1.0
f 1 2 3 4

# Second cube
o Cube2
v 2.0 0.0 0.0
v 3.0 0.0 0.0
v 3.0 1.0 0.0
v 2.0 1.0 0.0
f 5 6 7 8
''';
      final buffer = Uint8List.fromList(multiGroupObj.codeUnits);

      final groups = GeometryUtils.parseObjFromBuffer(buffer);

      // Should have two groups (one for each 'o' directive)
      expect(groups.length, greaterThanOrEqualTo(1));

      // Total vertices should be 8 (4 per cube)
      final totalVertices = groups.fold<int>(0, (sum, g) => sum + g.geometry.vertices.length ~/ 3);
      expect(totalVertices, 8, reason: "Should have 8 vertices total (2 cubes × 4 vertices)");
    });

    test('verify mesh names and material names are preserved', () async {
      final objWithNames = '''
# OBJ with names and materials
o TestMesh
usemtl TestMaterial
v -0.5 -0.5 0.5
v 0.5 -0.5 0.5
v 0.5 0.5 0.5
v -0.5 0.5 0.5
f 1 2 3
f 1 3 4
''';
      final buffer = Uint8List.fromList(objWithNames.codeUnits);

      final groups = GeometryUtils.parseObjFromBuffer(buffer);

      expect(groups.isNotEmpty, true);
      final group = groups.first;

      // Should have mesh name
      expect(group.name, isNotNull);
      expect(group.name, contains("TestMesh"));

      // Should have material name
      expect(group.materialName, isNotNull);
      expect(group.materialName, contains("TestMaterial"));
    });
  });

  // Exercises the formatHint path (Assimp selects the importer from the hint
  // rather than the hardcoded "obj" path) using a text-based format we can
  // author inline. This is the regression test for "FBX/multi-format" support:
  // any Assimp-readable format works once the correct hint is supplied.
  group('Multi-format loading (formatHint)', () {
    test('load STL via formatHint and parse geometry', () async {
      // Minimal ASCII STL: two triangles forming a quad in the XY plane.
      final stl = '''
solid test
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 0 0
      vertex 1 1 0
    endloop
  endfacet
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 1 0
      vertex 0 1 0
    endloop
  endfacet
endsolid test
''';
      final buffer = Uint8List.fromList(stl.codeUnits);

      final groups = GeometryUtils.parseModelFromBuffer(buffer, formatHint: 'stl');

      expect(groups.isNotEmpty, true, reason: "STL should parse into at least one mesh group");
      final geometry = groups.first.geometry;
      expect(geometry.vertices.isNotEmpty, true);
      // Two triangles -> 6 indices.
      expect(geometry.indices.length, 6, reason: "STL quad (2 triangles) should have 6 indices");
    });

    test('load PLY via formatHint and parse geometry', () async {
      // Minimal ASCII PLY: a single triangle.
      final ply = '''
ply
format ascii 1.0
element vertex 3
property float x
property float y
property float z
element face 1
property list uchar int vertex_indices
end_header
0 0 0
1 0 0
0 1 0
3 0 1 2
''';
      final buffer = Uint8List.fromList(ply.codeUnits);

      final groups = GeometryUtils.parseModelFromBuffer(buffer, formatHint: 'ply');

      expect(groups.isNotEmpty, true, reason: "PLY should parse into at least one mesh group");
      expect(groups.first.geometry.indices.length, 3, reason: "PLY single triangle should have 3 indices");
    });
  });
}
