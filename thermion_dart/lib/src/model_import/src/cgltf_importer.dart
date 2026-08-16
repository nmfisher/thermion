import 'package:thermion_dart/thermion_dart.dart';

/// The `allocate` shim (see bindings/src/ffi.dart and its js_interop
/// counterpart) hands out pointer-sized slots and only supports
/// Char/Pointer elements. TMeshData spans several slots, so request the
/// ceiling in pointer units and cast.
final int _tMeshDataSlots = (sizeOf<TMeshData>() + sizeOf<Pointer>() - 1) ~/ sizeOf<Pointer>();

/// [ModelFileImporter] backed by the cgltf parser compiled into the
/// Filament build (always available, no opt-in).
///
/// Handles glTF/glb only. Extracts positions and triangle-list indices
/// (strips/fans are expanded to triangle lists natively, in the single
/// shared implementation in `TGltfParser.cpp`); normals/UVs/names are not
/// extracted by this path. Used mainly for physics collision meshes.
class CgltfImporter implements ModelFileImporter {
  @override
  bool get isSupported => true;

  @override
  List<RawMesh> parse(Uint8List data, {String formatHint = 'gltf', String? meshName}) {
    final meshNamePtr = meshName != null ? meshName.toNativeUtf8().cast<Char>() : nullptr;

    final outMeshData = allocate<PointerClass>(_tMeshDataSlots).cast<TMeshData>();

    try {
      final result = GltfParser_parseBuffer(data.address, data.length, meshNamePtr, outMeshData);

      if (result != 0) {
        // The shim allocates zeroed memory, so disposing a partially filled
        // struct is safe (MeshData_dispose tolerates null pointers).
        MeshData_dispose(outMeshData);
        free(outMeshData);
        throw Exception('Failed to parse glTF (error code: $result)');
      }

      // Ownership of the struct and its malloc'd buffers moves into the
      // RawMesh; freed by RawMesh.dispose, not here.
      return [RawMesh.fromNative(outMeshData)];
    } finally {
      if (meshNamePtr != nullptr) {
        free(meshNamePtr);
      }
    }
  }
}
