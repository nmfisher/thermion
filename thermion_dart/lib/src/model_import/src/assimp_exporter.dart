import 'package:thermion_dart/thermion_dart.dart';

// The `allocate` shim (see bindings/src/ffi.dart and its js_interop
// counterpart) hands out pointer-sized slots and only supports
// Char/Pointer elements. TMeshData spans several slots, so request the
// ceiling in pointer units and cast.
final int _tMeshDataSlots = (sizeOf<TMeshData>() + sizeOf<Pointer>() - 1) ~/ sizeOf<Pointer>();

/// Assimp export-format ids keyed by file extension. Only FBX is compiled
/// into the shipped libassimp (see scripts/patch_libassimp_tnt.py).
const Map<String, String> _assimpFormatIds = {'fbx': 'fbx', 'fbxa': 'fbxa'};

/// [ModelFileExporter] backed by the Assimp native library.
///
/// Writes the meshes into one in-memory scene (a named mesh, node and
/// material per [RawMesh]) and encodes it with Assimp's FBX exporter. The
/// returned bytes round trip: [AssimpImporter] reads them back into the
/// same mesh data.
///
/// Assimp is opt-in at link time: [isSupported] returns false unless the
/// native library was built with `assimp: true` under
/// `hooks.user_defines.thermion_dart`.
class AssimpExporter implements ModelFileExporter {
  @override
  bool get isSupported => ModelExporter_isSupported();

  @override
  Uint8List export(List<RawMesh> meshes, {required String formatHint}) {
    if (!isSupported) {
      throw UnsupportedError(
        'Assimp model export is not compiled into this build. Rebuild the '
        'native library with the Assimp feature enabled (set THERMION_ASSIMP=1 '
        'when running the platform build script, and add `assimp: true` under '
        'hooks.user_defines.thermion_dart in your pubspec.yaml).',
      );
    }
    if (meshes.isEmpty) {
      throw ArgumentError.value(meshes, 'meshes', 'cannot export an empty mesh list');
    }
    final formatId = _assimpFormatIds[formatHint.toLowerCase()];
    if (formatId == null) {
      throw ArgumentError.value(
        formatHint,
        'formatHint',
        'only FBX export is compiled into this build (use "fbx" for binary or "fbxa" for ASCII)',
      );
    }

    // Everything allocated below is freed in the finally block; the native
    // export buffer is the only exception (disposed through its own API).
    final transient = <Pointer>[];

    Pointer<Float> floatBuffer(Float32List data) {
      // Char-typed slots are bytes; floats need 4 per element.
      final pointer = allocate<Char>(data.length * 4).cast<Float>();
      transient.add(pointer);
      pointer.asTypedList(data.length).setAll(0, data);
      return pointer;
    }

    try {
      final meshesPtr = allocate<PointerClass>(_tMeshDataSlots * meshes.length).cast<TMeshData>();
      transient.add(meshesPtr);

      for (int i = 0; i < meshes.length; i++) {
        final mesh = meshes[i];
        final ref = (meshesPtr + i).ref;

        if (mesh.name == null) {
          ref.name = nullptr;
        } else {
          ref.name = mesh.name!.toNativeUtf8().cast<Char>();
          transient.add(ref.name);
        }
        if (mesh.materialName == null) {
          ref.materialName = nullptr;
        } else {
          ref.materialName = mesh.materialName!.toNativeUtf8().cast<Char>();
          transient.add(ref.materialName);
        }

        ref.vertices = floatBuffer(mesh.positions);
        ref.vertexCount = mesh.positions.length;
        if (mesh.normals.isNotEmpty) {
          ref.normals = floatBuffer(mesh.normals);
          ref.normalCount = mesh.normals.length;
        }
        if (mesh.uvs.isNotEmpty) {
          ref.uvs = floatBuffer(mesh.uvs);
          ref.uvCount = mesh.uvs.length;
        }
        if (mesh.indices.isNotEmpty) {
          final indices = allocate<Char>(mesh.indices.length * 4).cast<Uint32>();
          transient.add(indices);
          indices.asTypedList(mesh.indices.length).setAll(0, mesh.indices);
          ref.indices = indices;
          ref.indexCount = mesh.indices.length;
        }
        ref.primitiveType = mesh.primitiveType.index;
      }

      final formatPointer = formatId.toNativeUtf8().cast<Char>();
      transient.add(formatPointer);
      final outSizePointer = allocate<Int64>(1);
      transient.add(outSizePointer);

      final outPointer = ModelExporter_exportToBuffer(meshesPtr, meshes.length, formatPointer, outSizePointer);
      if (outPointer == nullptr) {
        throw Exception('Failed to export ${meshes.length} mesh(es) to $formatHint (see native logs)');
      }
      final size = outSizePointer.value;
      // Take the caller-owned copy before releasing the native buffer.
      final result = Uint8List.fromList(outPointer.asTypedList(size));
      ModelExporter_disposeBuffer(outPointer);
      return result;
    } finally {
      for (final pointer in transient) {
        free(pointer);
      }
    }
  }
}
