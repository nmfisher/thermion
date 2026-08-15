import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';

import '../../../filament/src/implementation/ffi_model_importer.dart';

class GeometryUtils {
  /// Expand triangle strip indices to triangle list indices.
  ///
  /// OpenGL/glTF triangle strip convention:
  /// - Triangle i (even): v[i], v[i+1], v[i+2]
  /// - Triangle i (odd):  v[i+1], v[i], v[i+2]
  ///
  /// This maintains consistent front-face winding (CCW).
  static List<int> expandTriangleStrip(List<int> stripIndices) {
    if (stripIndices.length < 3) {
      return [];
    }

    final numTriangles = stripIndices.length - 2;
    final triangleIndices = <int>[];

    for (int i = 0; i < numTriangles; i++) {
      final i0 = stripIndices[i];
      final i1 = stripIndices[i + 1];
      final i2 = stripIndices[i + 2];

      // OpenGL triangle strip winding convention
      if (i % 2 == 0) {
        // Even triangles: v[i], v[i+1], v[i+2]
        triangleIndices.add(i0);
        triangleIndices.add(i1);
        triangleIndices.add(i2);
      } else {
        // Odd triangles: v[i+1], v[i], v[i+2]
        triangleIndices.add(i1);
        triangleIndices.add(i0);
        triangleIndices.add(i2);
      }
    }

    return triangleIndices;
  }

  /// Duplicate vertices so each triangle has unique vertices,
  /// and add barycentric coordinates to CUSTOM0 (attribute0).
  ///
  /// For each triangle (i0, i1, i2):
  /// - Vertex at i0 gets barycentric (1, 0, 0, 0)
  /// - Vertex at i1 gets barycentric (0, 1, 0, 0)
  /// - Vertex at i2 gets barycentric (0, 0, 1, 0)
  ///
  /// Returns a new Geometry with duplicated vertices and sequential indices.
  static Geometry duplicateVerticesWithBarycentrics(Float32List vertices, List<int> indices) {
    if (indices.isEmpty) {
      throw ArgumentError('Indices list cannot be empty');
    }
    if (indices.length % 3 != 0) {
      throw ArgumentError('Indices count must be a multiple of 3 (triangles)');
    }

    final triangleCount = indices.length ~/ 3;
    final newVertexCount = triangleCount * 3;
    final newVertices = Float32List(newVertexCount * 3);
    final newBarycentrics = Float32List(newVertexCount * 4); // CUSTOM0 is FLOAT4
    final newIndices = Int32List(newVertexCount);

    // Barycentric coordinates for each triangle vertex (4 components for
    // FLOAT4)
    const bary1 = [1.0, 0.0, 0.0, 0.0]; // vertex 0
    const bary2 = [0.0, 1.0, 0.0, 0.0]; // vertex 1
    const bary3 = [0.0, 0.0, 1.0, 0.0]; // vertex 2

    for (int t = 0; t < triangleCount; t++) {
      final i0 = indices[t * 3 + 0];
      final i1 = indices[t * 3 + 1];
      final i2 = indices[t * 3 + 2];

      final outIdx = t * 3;

      // Copy vertex 0 and assign barycentric (1, 0, 0)
      _copyVertex(vertices, i0, newVertices, outIdx + 0);
      _copyBarycentric(bary1, newBarycentrics, outIdx + 0);
      newIndices[outIdx + 0] = outIdx + 0;

      // Copy vertex 1 and assign barycentric (0, 1, 0)
      _copyVertex(vertices, i1, newVertices, outIdx + 1);
      _copyBarycentric(bary2, newBarycentrics, outIdx + 1);
      newIndices[outIdx + 1] = outIdx + 1;

      // Copy vertex 2 and assign barycentric (0, 0, 1)
      _copyVertex(vertices, i2, newVertices, outIdx + 2);
      _copyBarycentric(bary3, newBarycentrics, outIdx + 2);
      newIndices[outIdx + 2] = outIdx + 2;
    }

    return Geometry(
      newVertices,
      newIndices,
      attribute0: newBarycentrics,
      primitiveType: PrimitiveType.TRIANGLES,
      indexType: IndexType.UINT,
      createDummyColors: false,
      createDummyUvs: false,
    );
  }

  static void _copyVertex(Float32List src, int srcIndex, Float32List dst, int dstIndex) {
    final srcOffset = srcIndex * 3;
    final dstOffset = dstIndex * 3;
    dst[dstOffset + 0] = src[srcOffset + 0];
    dst[dstOffset + 1] = src[srcOffset + 1];
    dst[dstOffset + 2] = src[srcOffset + 2];
  }

  static void _copyBarycentric(List<double> src, Float32List dst, int dstIndex) {
    final dstOffset = dstIndex * 4; // FLOAT4
    dst[dstOffset + 0] = src[0];
    dst[dstOffset + 1] = src[1];
    dst[dstOffset + 2] = src[2];
    dst[dstOffset + 3] = src[3];
  }

  static Geometry plane({double width = 1.0, double height = 1.0, bool normals = true, bool uvs = true}) {
    Float32List vertices = Float32List.fromList([
      -width / 2,
      0,
      -height / 2,
      width / 2,
      0,
      -height / 2,
      width / 2,
      0,
      height / 2,
      -width / 2,
      0,
      height / 2,
    ]);

    Float32List? _normals = normals ? Float32List.fromList([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]) : null;

    Float32List? _uvs = uvs ? Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]) : null;

    final indices = Uint16List.fromList([0, 2, 1, 0, 3, 2]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry groundPlane({bool normals = true, bool uvs = true}) {
    final vertices = Float32List.fromList([
      -1, 0, 1, // 0: front-left
      1, 0, 1, // 1: front-right
      1, 0, -1, // 2: back-right
      -1, 0, -1, // 3: back-left
    ]);

    final Float32List? _normals = normals
        ? Float32List.fromList([
            0, 1, 0, // Normal for vertex 0
            0, 1, 0, // Normal for vertex 1
            0, 1, 0, // Normal for vertex 2
            0, 1, 0, // Normal for vertex 3
          ])
        : null;

    final Float32List? _uvs = uvs
        ? Float32List.fromList([
            0, 1, // UV for vertex 0 (bottom-left)
            1, 1, // UV for vertex 1 (bottom-right)
            1, 0, // UV for vertex 2 (top-right)
            0, 0, // UV for vertex 3 (top-left)
          ])
        : null;

    final indices = Uint16List.fromList([
      0, 1, 2, // First triangle (front-right half)
      0, 2, 3, // Second triangle (back-left half)
    ]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry fromAabb3(Aabb3 aabb, {bool normals = true, bool uvs = true}) {
    // Get the center and half extents from the AABB
    final center = aabb.center;
    final halfExtents = Vector3.zero();
    aabb.copyCenterAndHalfExtents(center, halfExtents);

    // Create vertices list with transformed coordinates
    final vertices = Float32List.fromList([
      // Front face
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,

      // Back face
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,

      // Top face
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,

      // Bottom face
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,

      // Right face
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
      center.x + halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x + halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,

      // Left face
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z - halfExtents.z,
      center.x - halfExtents.x, center.y - halfExtents.y,
      center.z + halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z + halfExtents.z,
      center.x - halfExtents.x, center.y + halfExtents.y,
      center.z - halfExtents.z,
    ]);

    final _normals = normals
        ? Float32List.fromList([
            // Front face
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,
            0, 0, 1,

            // Back face
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,
            0, 0, -1,

            // Top face
            0, 1, 0,
            0, 1, 0,
            0, 1, 0,
            0, 1, 0,

            // Bottom face
            0, -1, 0,
            0, -1, 0,
            0, -1, 0,
            0, -1, 0,

            // Right face
            1, 0, 0,
            1, 0, 0,
            1, 0, 0,
            1, 0, 0,

            // Left face
            -1, 0, 0,
            -1, 0, 0,
            -1, 0, 0,
            -1, 0, 0,
          ])
        : null;

    final _uvs = uvs
        ? Float32List.fromList([
            // Front face
            1 / 3, 1 / 3,
            2 / 3, 1 / 3,
            2 / 3, 2 / 3,
            1 / 3, 2 / 3,

            // Back face
            2 / 3, 2 / 3,
            2 / 3, 1,
            1, 1,
            1, 2 / 3,

            // Top face
            1 / 3, 0,
            1 / 3, 1 / 3,
            2 / 3, 1 / 3,
            2 / 3, 0,

            // Bottom face
            1 / 3, 2 / 3,
            2 / 3, 2 / 3,
            2 / 3, 1,
            1 / 3, 1,

            // Right face
            2 / 3, 1 / 3,
            2 / 3, 2 / 3,
            1, 2 / 3,
            1, 1 / 3,

            // Left face
            0, 1 / 3,
            1 / 3, 1 / 3,
            1 / 3, 2 / 3,
            0, 2 / 3,
          ])
        : null;

    final indices = Uint16List.fromList([
      // Front face
      0, 1, 2, 0, 2, 3,
      // Back face
      4, 5, 6, 4, 6, 7,
      // Top face
      8, 9, 10, 8, 10, 11,
      // Bottom face
      12, 13, 14, 12, 14, 15,
      // Right face
      16, 17, 18, 16, 18, 19,
      // Left face
      20, 21, 22, 20, 22, 23,
    ]);

    return Geometry(vertices, indices, normals: _normals, uvs: _uvs);
  }

  static Geometry camera({
    double bodyWidth = 0.6,
    double bodyHeight = 0.7,
    double bodyDepth = 1.4,
    double lensRadius = 0.3,
    double lensLength = 0.4,
    bool normals = true,
    bool uvs = true,
  }) => CameraGeometry.camera(
    bodyWidth: bodyWidth,
    bodyHeight: bodyHeight,
    bodyDepth: bodyDepth,
    lensRadius: lensRadius,
    lensLength: lensLength,
    normals: normals,
    uvs: uvs,
  );

  static Geometry wireframeCamera({
    double sphereRadius = 0.2,
    double frustumDistance = 1.0,
    double frustumNear = 0.5,
    double frustumFar = 1.0,
    double fov = pi / 3,
    bool normals = true,
    bool uvs = true,
    double wireThickness = 0.01,
  }) => CameraGeometry.wireframeCamera(
    sphereRadius: sphereRadius,
    frustumDistance: frustumDistance,
    frustumNear: frustumNear,
    frustumFar: frustumFar,
    fov: fov,
    normals: normals,
    uvs: uvs,
    wireThickness: wireThickness,
  );

  static Geometry cube({bool normals = true, bool uvs = true, bool flipUvs = true}) =>
      CubeGeometry.cube(normals: normals, uvs: uvs, flipUvs: flipUvs);

  static Geometry cylinder({double radius = 1.0, double length = 1.0, bool normals = true, bool uvs = true}) =>
      CylinderGeometry.cylinder(radius: radius, length: length, normals: normals, uvs: uvs);

  static Geometry conic({double radius = 1.0, double length = 1.0, bool normals = true, bool uvs = true}) =>
      CylinderGeometry.conic(radius: radius, length: length, normals: normals, uvs: uvs);

  static Geometry halfPyramid({
    double startX = 0.25,
    double startY = 0.25,
    double width = 1.0,
    double height = 1.0,
    double depth = 1.0,
    bool normals = true,
    bool uvs = true,
  }) => PyramidGeometry.halfPyramid(
    startX: startX,
    startY: startY,
    width: width,
    height: height,
    depth: depth,
    normals: normals,
    uvs: uvs,
  );

  static Geometry fullscreenQuad() => QuadGeometry.fullscreenQuad();

  static Geometry quad() => QuadGeometry.quad();

  static Geometry sphere({bool normals = true, bool uvs = true, int latitudeBands = 20, int longitudeBands = 20}) =>
      SphereGeometry.sphere(normals: normals, uvs: uvs, latitudeBands: latitudeBands, longitudeBands: longitudeBands);

  /// Parses a model file from the given byte buffer and returns a list of
  /// geometry groups. Each group corresponds to a named object/mesh (or
  /// material partition) in the file.
  ///
  /// [formatHint] is the file extension *without* the dot (e.g. "obj", "fbx",
  /// "glb", "stl", "ply"); Assimp uses it to select the right importer when
  /// reading from memory.
  ///
  /// [flipUvs] - If true (default), flips UV coordinates vertically. Most
  ///            formats (OBJ, FBX) use bottom-left UV origin, while Filament
  ///            uses top-left. Flipping is applied here only (not in native
  ///            Assimp), so it is not double-applied.
  ///
  /// Returns a list of [ModelGeometryGroup] objects.
  static List<ModelGeometryGroup> parseModelFromBuffer(
    Uint8List data, {
    required String formatHint,
    bool flipUvs = true,
  }) {
    final meshes = ModelImporter.loadFromBuffer(data, formatHint: formatHint);
    return meshes.map((mesh) {
      final geometry = mesh.toGeometry(
        flipUvs: flipUvs,
        createDummyColors: true,
        createDummyUvs: true,
      );
      return ModelGeometryGroup(
        name: mesh.name,
        materialName: mesh.materialName,
        geometry: geometry,
      );
    }).toList();
  }

  /// Convenience wrapper for OBJ files (equivalent to
  /// [parseModelFromBuffer] with [formatHint] `"obj"`).
  static List<ModelGeometryGroup> parseObjFromBuffer(Uint8List data,
          {bool flipUvs = true}) =>
      parseModelFromBuffer(data, formatHint: 'obj', flipUvs: flipUvs);
}

/// Represents a geometry group parsed from a model file.
///
/// A model file can contain multiple objects/meshes, each with its own
/// material assignment. This class represents one such group.
class ModelGeometryGroup {
  /// Object/mesh name.
  final String? name;

  /// Material name.
  final String? materialName;

  /// The geometry data for this group.
  final Geometry geometry;

  ModelGeometryGroup({
    this.name,
    this.materialName,
    required this.geometry,
  });
}
