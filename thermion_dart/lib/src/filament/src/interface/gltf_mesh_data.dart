import 'package:thermion_dart/thermion_dart.dart';

/// Contains mesh geometry data extracted from a glTF file for physics collision detection.
class GltfMeshData {
  /// Vertex positions as xyz floats (length = vertexCount * 3)
  final Float32List vertices;

  /// Optional triangle indices
  final Uint32List? indices;

  /// Primitive type (e.g., TRIANGLES, POINTS, etc.)
  final PrimitiveType primitiveType;

  GltfMeshData({
    required this.vertices,
    this.indices,
    required this.primitiveType,
  });

  /// Parse glTF file and extract geometry data for physics collision detection.
  /// Returns vertex positions (xyz) and optional indices.
  /// If [meshName] is specified, only extracts data for that specific mesh.
  static Future<GltfMeshData> parse(Uint8List data, {String? meshName}) async {
    // Implementation will be provided by the FFI layer
    throw UnimplementedError('Must be called on FFI implementation');
  }
}
