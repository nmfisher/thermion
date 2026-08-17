import 'package:thermion_dart/thermion_dart.dart';

/// Native (dart:ffi) implementation of [FFIGltfMeshData.parse]: calls
/// GltfParser_parseBuffer through the ffigen bindings and copies the
/// malloc'd native buffers into plain Dart lists.
Future<({Float32List vertices, Uint32List? indices, PrimitiveType primitiveType})> parseGltfMeshData(
  Uint8List data,
  String? meshName,
) async {
  final meshNamePtr = meshName != null ? meshName.toNativeUtf8().cast<Char>() : nullptr;

  final outMeshData = allocate<TMeshData>(sizeOf<TMeshData>());

  try {
    final result = GltfParser_parseBuffer(data.address, data.length, meshNamePtr, outMeshData);

    if (result != 0) {
      // The shim allocates zeroed memory, so disposing a partially filled
      // struct is safe (MeshData_dispose tolerates null pointers).
      MeshData_dispose(outMeshData);
      free(outMeshData);
      throw Exception('Failed to parse glTF (error code: $result)');
    }

    // The consumer takes a copy: [GltfMeshData] is a plain public data
    // holder with no dispose hook, and physics keeps it for the lifetime of
    // the collision object, so the native buffers cannot be tied to it.
    // Copying lets the parser's native memory be released right away
    // instead of being held until process exit.
    final ref = outMeshData.ref;
    final parsed = (
      vertices: Float32List.fromList(ref.vertices.asTypedList(ref.vertexCount)),
      indices: ref.indexCount > 0 && ref.indices != nullptr
          ? Uint32List.fromList(ref.indices.asTypedList(ref.indexCount))
          : null,
      primitiveType: PrimitiveType.values[ref.primitiveType],
    );

    MeshData_dispose(outMeshData);
    free(outMeshData);
    return parsed;
  } finally {
    if (meshNamePtr != nullptr) {
      free(meshNamePtr);
    }
  }
}
