import 'package:thermion_dart/thermion_dart.dart';

import 'ffi_gltf_mesh_data_parse.dart';

/// [GltfMeshData] produced by the cgltf parser compiled into the Filament
/// build (`GltfParser_parseBuffer`).
///
/// Concrete type returned by `FilamentApp.parseGltf` (public API). The FFI
/// walk lives behind a conditional import (ffi_gltf_mesh_data_parse.dart):
/// struct field access is native-only, and the web bindings keep structs
/// opaque.
class FFIGltfMeshData extends GltfMeshData {
  FFIGltfMeshData({required super.vertices, super.indices, required super.primitiveType});

  /// Parse glTF file to extract vertex/index data.
  /// Returns vertex positions (xyz) and optional indices.
  /// If [meshName] is specified, only extracts data for that specific mesh.
  static Future<GltfMeshData> parse(Uint8List data, {String? meshName}) async {
    final parsed = await parseGltfMeshData(data, meshName);
    return FFIGltfMeshData(vertices: parsed.vertices, indices: parsed.indices, primitiveType: parsed.primitiveType);
  }
}
