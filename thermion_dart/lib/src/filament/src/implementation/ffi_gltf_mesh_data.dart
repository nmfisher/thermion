import 'package:thermion_dart/thermion_dart.dart';

class FFIGltfMeshData extends GltfMeshData {
  FFIGltfMeshData({
    required super.vertices,
    super.indices,
    required super.primitiveType,
  });

  /// Parse glTF file to extract vertex/index data.
  /// Returns vertex positions (xyz) and optional indices.
  /// If [meshName] is specified, only extracts data for that specific mesh.
  static Future<GltfMeshData> parse(Uint8List data, {String? meshName}) async {
    final meshNamePtr =
        meshName != null ? meshName.toNativeUtf8().cast<Char>() : nullptr;

    final meshData = Struct.create<TGltfMeshData>();

    try {
      final result = GltfParser_parseBuffer(
        data.address,
        data.length,
        meshNamePtr,
        meshData.address,
      );

      if (result != 0) {
        throw Exception(
          "Failed to parse glTF for physics (error code: $result)",
        );
      }

      // Copy to Dart lists
      final vertices = Float32List(meshData.vertexCount);
      vertices.setRange(
        0,
        vertices.length,
        meshData.vertices.asTypedList(meshData.vertexCount),
      );

      Uint32List? indices;
      if (meshData.indices != nullptr && meshData.indexCount > 0) {
        indices = Uint32List(meshData.indexCount);
        indices.setRange(
          0,
          indices.length,
          meshData.indices.asTypedList(meshData.indexCount),
        );
      }

      GltfParser_freeMeshData(meshData.address);

      return FFIGltfMeshData(
        vertices: vertices,
        indices: indices,
        primitiveType: PrimitiveType.values[meshData.primitiveType],
      );
    } finally {
      if (meshNamePtr != nullptr) {
        free(meshNamePtr);
      }
    }
  }
}
