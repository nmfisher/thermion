// Manual FFI bindings for glTF parser
import 'dart:ffi' as ffi;

/// Struct containing mesh geometry data from parsed glTF
final class TGltfMeshData extends ffi.Struct {
  external ffi.Pointer<ffi.Float> vertices;

  @ffi.Uint32()
  external int vertexCount;

  external ffi.Pointer<ffi.Uint32> indices;

  @ffi.Uint32()
  external int indexCount;

  @ffi.Uint32()
  external int primitiveType;
}

/// Parse glTF buffer and extract mesh geometry data
/// Returns 0 on success, non-zero on failure
@ffi.Native<ffi.Int Function(
  ffi.Pointer<ffi.Uint8>,
  ffi.Size,
  ffi.Pointer<ffi.Char>,
  ffi.Pointer<TGltfMeshData>
)>(isLeaf: true)
external int GltfParser_parseBuffer(
  ffi.Pointer<ffi.Uint8> data,
  int length,
  ffi.Pointer<ffi.Char> meshName,
  ffi.Pointer<TGltfMeshData> outMeshData,
);

/// Free parsed mesh data
@ffi.Native<ffi.Void Function(ffi.Pointer<TGltfMeshData>)>(isLeaf: true)
external void GltfParser_freeMeshData(
  ffi.Pointer<TGltfMeshData> meshData,
);
