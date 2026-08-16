import 'package:thermion_dart/thermion_dart.dart';

/// [GltfMeshData] produced by the cgltf side of the model-import facade.
///
/// Kept as the concrete type returned by `FilamentApp.parseGltf` (public
/// API); parsing itself now lives in [CgltfImporter].
class FFIGltfMeshData extends GltfMeshData {
  FFIGltfMeshData({required super.vertices, super.indices, required super.primitiveType});

  /// Parse glTF file to extract vertex/index data.
  /// Returns vertex positions (xyz) and optional indices.
  /// If [meshName] is specified, only extracts data for that specific mesh.
  static Future<GltfMeshData> parse(Uint8List data, {String? meshName}) async {
    final raw = CgltfImporter().parse(data, formatHint: 'gltf', meshName: meshName).first;
    return FFIGltfMeshData(
      vertices: raw.positions,
      indices: raw.indices.isEmpty ? null : raw.indices,
      primitiveType: raw.primitiveType,
    );
  }
}
