import 'package:thermion_dart/thermion_dart.dart';

/// Contains mesh geometry data extracted from a glTF file for physics collision detection.
abstract class GltfMeshData {
  /// Vertex positions as xyz floats (length = vertexCount * 3)
  final Float32List vertices;

  /// Optional triangle indices
  final Uint32List? indices;

  /// Primitive type (e.g., TRIANGLES, POINTS, etc.)
  final PrimitiveType primitiveType;

  GltfMeshData({required this.vertices, this.indices, required this.primitiveType});
}
