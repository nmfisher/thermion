import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

/// A quad (two triangles) in the XZ plane, matching the shape
/// GeometryUtils.plane produces.
RawMesh _quadMesh({String? name = "TestQuad", String? materialName = "TestMaterial"}) {
  return RawMesh(
    name: name,
    materialName: materialName,
    positions: Float32List.fromList([
      -1.0, 0.0, 1.0, // 0: front-left
      1.0, 0.0, 1.0, // 1: front-right
      1.0, 0.0, -1.0, // 2: back-right
      -1.0, 0.0, -1.0, // 3: back-left
    ]),
    normals: Float32List.fromList([
      0, 1, 0, //
      0, 1, 0,
      0, 1, 0,
      0, 1, 0,
    ]),
    uvs: Float32List.fromList([
      0, 1, //
      1, 1,
      1, 0,
      0, 0,
    ]),
    indices: Uint32List.fromList([
      0, 1, 2, //
      0, 2, 3,
    ]),
    primitiveType: PrimitiveType.TRIANGLES,
  );
}

void main() async {
  final testHelper = TestHelper("model_export");
  await testHelper.setup();

  group('FBX export (ModelFileExporter facade)', () {
    test('isSupported is true in this build', () {
      expect(AssimpExporter().isSupported, true, reason: "Tests require a build with Assimp enabled");
    });

    test('export writes binary FBX magic bytes', () {
      final fbx = AssimpExporter().export([_quadMesh()], formatHint: 'fbx');

      expect(fbx.isNotEmpty, true, reason: "Export should produce bytes");
      // Binary FBX files start with the 18-byte magic "Kaydara FBX Binary".
      final magic = String.fromCharCodes(fbx.take(18));
      expect(magic, "Kaydara FBX Binary", reason: "Exported file should be binary FBX");
    });

    test('export ASCII FBX when hinted', () {
      final fbx = AssimpExporter().export([_quadMesh()], formatHint: 'fbxa');

      expect(fbx.isNotEmpty, true);
      // ASCII FBX files start with a "; FBX ..." comment header.
      final header = String.fromCharCodes(fbx.take(200));
      expect(header.startsWith("; FBX"), true, reason: "ASCII FBX should start with '; FBX' comment");
    });

    test('export rejects unsupported formats and empty mesh lists', () {
      final exporter = AssimpExporter();
      expect(() => exporter.export([_quadMesh()], formatHint: 'obj'), throwsArgumentError,
          reason: "Only FBX is compiled in");
      expect(() => exporter.export([], formatHint: 'fbx'), throwsArgumentError);
    });

    test('FBX round trip: export then re-import preserves the mesh', () {
      final mesh = _quadMesh();
      final fbx = AssimpExporter().export([mesh], formatHint: 'fbx');
      expect(fbx.isNotEmpty, true);

      final meshes = AssimpImporter().parse(fbx, formatHint: 'fbx');
      try {
        expect(meshes.length, 1, reason: "Exported scene should contain exactly one mesh");
        final imported = meshes.first;

        // Topology survives the round trip.
        expect(imported.indices.length, 6, reason: "Quad (2 triangles) should re-import with 6 indices");
        expect(imported.positions.length, 12, reason: "Quad should re-import with 4 vertices (12 floats)");
        expect(imported.primitiveType, PrimitiveType.TRIANGLES);

        // Geometry survives (compare the axis-aligned bounds rather than
        // per-vertex order — the FBX pipeline may re-order vertices and/or
        // apply a uniform unit conversion).
        final (min, max) = _bounds(imported.positions);
        expect(min.$1, closeTo(-1.0, 0.01));
        expect(max.$1, closeTo(1.0, 0.01));
        expect(min.$2, closeTo(0.0, 0.01));
        expect(max.$2, closeTo(0.0, 0.01));
        expect(min.$3, closeTo(-1.0, 0.01));
        expect(max.$3, closeTo(1.0, 0.01));

        print("Round-tripped mesh name: ${imported.name}");
        print("Round-tripped material name: ${imported.materialName}");
        expect(imported.name, contains("TestQuad"), reason: "Mesh name should survive the round trip");
        expect(imported.materialName, contains("TestMaterial"), reason: "Material name should survive");
      } finally {
        for (final imported in meshes) {
          imported.dispose();
        }
      }
    });

    test('export takes multiple meshes into one scene', () {
      final meshes = [_quadMesh(name: "QuadA", materialName: "MatA"), _quadMesh(name: "QuadB", materialName: "MatB")];
      final fbx = AssimpExporter().export(meshes, formatHint: 'fbx');

      final imported = AssimpImporter().parse(fbx, formatHint: 'fbx');
      try {
        expect(imported.length, 2, reason: "Both meshes should re-import");
        final names = imported.map((mesh) => mesh.name ?? "").toSet();
        expect(names.length, 2, reason: "Mesh names should stay distinct: $names");
      } finally {
        for (final mesh in imported) {
          mesh.dispose();
        }
      }
    });
  });
}

/// Axis-aligned bounds of a flat xyz position buffer, as
/// ((minX, minY, minZ), (maxX, maxY, maxZ)).
((double, double, double), (double, double, double)) _bounds(Float32List positions) {
  var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity, maxZ = double.negativeInfinity;
  for (int i = 0; i < positions.length; i += 3) {
    final x = positions[i], y = positions[i + 1], z = positions[i + 2];
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (z < minZ) minZ = z;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
    if (z > maxZ) maxZ = z;
  }
  return ((minX, minY, minZ), (maxX, maxY, maxZ));
}
