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
    // This consumer takes a copy: [GltfMeshData] is a plain public data
    // holder with no dispose hook, and physics keeps it for the lifetime of
    // the collision object, so the native buffers cannot be tied to it.
    // Copying lets the importer's native memory be released right away
    // instead of being held until process exit.
    final mesh = FFIGltfMeshData(
      vertices: Float32List.fromList(raw.positions),
      indices: raw.indices.isEmpty ? null : Uint32List.fromList(raw.indices),
      primitiveType: raw.primitiveType,
    );
    raw.dispose();
    return mesh;
  }
}
