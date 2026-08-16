import 'package:thermion_dart/thermion_dart.dart';

/// The `allocate` shim (see bindings/src/ffi.dart and its js_interop
/// counterpart) hands out pointer-sized slots and only supports
/// Char/Pointer elements. TMeshData spans several slots, so request the
/// ceiling in pointer units and cast.
final int _tMeshDataSlots =
    (sizeOf<TMeshData>() + sizeOf<Pointer>() - 1) ~/ sizeOf<Pointer>();

/// [ModelFileImporter] backed by the Assimp native library.
///
/// Supports any format Assimp can read (OBJ, FBX, glTF/glb, STL, PLY, ...).
/// Mesh vertices/normals are already transformed into world space by the
/// native layer (accumulated `aiScene` node transforms), so multi-node
/// scenes come out correctly.
///
/// Assimp is opt-in at link time: [isSupported] returns false unless the
/// native library was built with `assimp: true` under
/// `hooks.user_defines.thermion_dart`.
class AssimpImporter implements ModelFileImporter {
  @override
  bool get isSupported => ModelImporter_isSupported();

  @override
  List<RawMesh> parse(Uint8List data, {required String formatHint}) {
    if (!isSupported) {
      throw UnsupportedError(
        'Assimp model loading is not compiled into this build. Rebuild the '
        'native library with the Assimp feature enabled (set THERMION_ASSIMP=1 '
        'when running the platform build script, and add `assimp: true` under '
        'hooks.user_defines.thermion_dart in your pubspec.yaml).',
      );
    }

    final dataPointer = allocate<Char>(data.length).cast<Uint8>();
    dataPointer.asTypedList(data.length).setAll(0, data);

    // Assimp's format hint: file extension without the leading dot.
    final hintPointer = formatHint.toNativeUtf8().cast<Char>();

    try {
      final importerPtr = ModelImporter_loadFromBuffer(dataPointer, data.length, hintPointer);

      if (importerPtr == nullptr) {
        throw Exception('Failed to load model ($formatHint): Assimp returned null importer');
      }

      try {
        final meshCount = ModelImporter_getMeshCount(importerPtr);
        if (meshCount == 0) {
          throw Exception('Failed to load model ($formatHint): No meshes found in file');
        }

        // One TMeshData slot reused for every mesh: getMesh fills it,
        // we copy to Dart memory, MeshData_dispose frees the native copy.
        final outMesh = allocate<PointerClass>(_tMeshDataSlots).cast<TMeshData>();
        final meshes = <RawMesh>[];

        try {
          for (int i = 0; i < meshCount; i++) {
            final result = ModelImporter_getMesh(importerPtr, i, outMesh);
            if (result != 0) {
              throw Exception('Failed to read mesh $i from model ($formatHint): error $result');
            }
            final ref = outMesh.ref;
            meshes.add(
              RawMesh(
                name: _safeDartString(ref.name),
                materialName: _safeDartString(ref.materialName),
                positions: _copyFloats(ref.vertices, ref.vertexCount),
                normals: _copyFloats(ref.normals, ref.normalCount),
                uvs: _copyFloats(ref.uvs, ref.uvCount),
                indices: _copyIndices(ref.indices, ref.indexCount),
                primitiveType: PrimitiveType.values[ref.primitiveType],
              ),
            );
            MeshData_dispose(outMesh);
          }
        } finally {
          MeshData_dispose(outMesh);
          free(outMesh);
        }

        return meshes;
      } finally {
        ModelImporter_destroy(importerPtr);
      }
    } finally {
      free(dataPointer);
      free(hintPointer);
    }
  }

  static Float32List _copyFloats(Pointer<Float> pointer, int count) {
    if (pointer == nullptr || count <= 0) {
      return Float32List(0);
    }
    return Float32List.fromList(pointer.asTypedList(count));
  }

  static Uint32List _copyIndices(Pointer<Uint32> pointer, int count) {
    if (pointer == nullptr || count <= 0) {
      return Uint32List(0);
    }
    return Uint32List.fromList(pointer.asTypedList(count));
  }

  /// Convert a C string pointer to a Dart string, null on null pointer or
  /// invalid UTF-8.
  static String? _safeDartString(Pointer<Char> ptr) {
    if (ptr == nullptr) return null;
    try {
      return ptr.cast<Utf8>().toDartString();
    } catch (_) {
      return null;
    }
  }
}
