import 'package:thermion_dart/thermion_dart.dart';

/// The single flat-mesh result type shared by every model-file import path
/// (Assimp and cgltf).
///
/// A [RawMesh] is one decomposed mesh of a model file: names plus vertex
/// attributes and indices, with no scene hierarchy. Positions/normals are
/// 3 floats per vertex, UVs are 2 floats per vertex (first channel only).
///
/// ## Buffer ownership
///
/// Meshes produced by an importer ([RawMesh.fromNative]) expose their
/// positions/normals/uvs/indices as typed-data **views** backed by native
/// memory owned by this object — no Dart-side copy is made. The buffers are
/// private copies that the native layer malloc'd when the mesh was read
/// (they are not tied to the importer or the parsed scene), so they stay
/// valid until [dispose] is called, even after the importer is destroyed.
///
/// - [dispose] frees the native buffers (exactly once; idempotent). After
///   it returns, the typed-data views are dangling and must not be read.
/// - A mesh that is never disposed keeps its native memory until the
///   process exits; there is no finalizer (see the bindings' explicit-
///   dispose convention).
/// - Meshes built through the public constructor own plain Dart lists and
///   need no disposal.
class RawMesh {
  /// Mesh/object name, or null when the file does not name the mesh.
  final String? name;

  /// Material name assigned to this mesh, or null.
  final String? materialName;

  /// Vertex positions (3 floats per vertex: x, y, z).
  final Float32List positions;

  /// Vertex normals (3 floats per normal). Empty when the mesh has none.
  final Float32List? _normals;

  /// First UV channel (2 floats per UV). Empty when the mesh has none.
  final Float32List? _uvs;

  /// Triangle indices (empty for non-indexed meshes).
  final Uint32List? _indices;

  /// Primitive type of the mesh. Both importers return triangle lists;
  /// strips/fans are expanded to triangles on the native side.
  final PrimitiveType primitiveType;

  /// The native struct whose buffers back this mesh's typed-data views.
  ///
  /// Null for meshes built from Dart-owned lists (public constructor) and
  /// after [dispose]. Owned exclusively by this object.
  Pointer<TMeshData>? _nativeData;

  RawMesh({
    required this.name,
    required this.materialName,
    required this.positions,
    Float32List? normals,
    Float32List? uvs,
    Uint32List? indices,
    this.primitiveType = PrimitiveType.TRIANGLES,
  }) : _normals = normals,
       _uvs = uvs,
       _indices = indices;

  /// Adopts a filled [TMeshData] and exposes its buffers as zero-copy
  /// typed-data views.
  ///
  /// Internal: called by the importers ([AssimpImporter], [CgltfImporter]).
  /// The struct must have been allocated through the bindings `allocate`
  /// shim and filled by native code that malloc'd each buffer; ownership of
  /// both the struct and the buffers moves into the returned [RawMesh] and
  /// is released by [dispose]. Names are decoded to Dart strings here
  /// (before any dispose could run).
  static RawMesh fromNative(Pointer<TMeshData> meshData) {
    final ref = meshData.ref;
    final mesh = RawMesh(
      name: _safeDartString(ref.name),
      materialName: _safeDartString(ref.materialName),
      positions: _float32View(ref.vertices, ref.vertexCount),
      normals: _float32View(ref.normals, ref.normalCount),
      uvs: _float32View(ref.uvs, ref.uvCount),
      indices: _uint32View(ref.indices, ref.indexCount),
      primitiveType: PrimitiveType.values[ref.primitiveType],
    );
    mesh._nativeData = meshData;
    return mesh;
  }

  /// Vertex normals, empty when the mesh has none.
  Float32List get normals => _normals ?? _emptyFloat32;

  /// First UV channel, empty when the mesh has none.
  Float32List get uvs => _uvs ?? _emptyFloat32;

  /// Triangle indices, empty for non-indexed meshes.
  Uint32List get indices => _indices ?? _emptyUint32;

  /// Number of vertices (positions.length ~/ 3).
  int get vertexCount => positions.length ~/ 3;

  /// Creates a [Geometry] ready to hand to `createGeometry`.
  ///
  /// Positions/normals (and unflipped UVs) flow through as the same
  /// typed-data views this mesh exposes; only UV flipping and USHORT index
  /// narrowing allocate. Keep this mesh undisposed until the geometry has
  /// been uploaded (see [dispose]).
  ///
  /// [flipUvs] flips UV coordinates vertically (v = 1.0 - v) when the source
  /// format uses a bottom-left UV origin (most formats do; Filament uses
  /// top-left). Flipping happens here only, never in native Assimp, so it is
  /// never double-applied.
  Geometry toGeometry({bool flipUvs = false, bool createDummyColors = true, bool createDummyUvs = true}) {
    final Float32List? processedUvs = uvs.isEmpty ? null : (flipUvs ? _flipUVs(uvs) : uvs);

    final indexType = indices.length <= 65535 ? IndexType.USHORT : IndexType.UINT;

    final List<int> convertedIndices;
    if (indexType == IndexType.USHORT) {
      // Narrow through a typed list — no boxed per-element allocation.
      convertedIndices = Uint16List.fromList(indices);
    } else {
      convertedIndices = indices;
    }

    return Geometry(
      positions,
      convertedIndices,
      normals: normals.isEmpty ? null : normals,
      uvs: processedUvs,
      indexType: indexType,
      createDummyColors: createDummyColors,
      createDummyUvs: createDummyUvs,
    );
  }

  /// Releases the native buffers backing this mesh's views.
  ///
  /// Idempotent; a no-op for meshes built from Dart-owned lists. After this
  /// returns, the typed-data views ([positions], [normals], [uvs],
  /// [indices]) point to freed memory and must not be read — so only call
  /// it once every consumer of the buffers is done (for geometry created
  /// with `createGeometry`, that is once the upload has completed; the
  /// upload copies synchronously before its future resolves).
  void dispose() {
    final native = _nativeData;
    if (native == null) return;
    _nativeData = null;
    MeshData_dispose(native); // frees the buffers (native malloc/free)
    free(native); // frees the shim-allocated struct itself
  }

  static Float32List _flipUVs(Float32List uvs) {
    final result = Float32List(uvs.length);
    for (int i = 0; i < uvs.length; i += 2) {
      result[i] = uvs[i]; // u unchanged
      result[i + 1] = 1.0 - uvs[i + 1]; // v flipped
    }
    return result;
  }

  /// Zero-copy view over a native float buffer, or an empty (Dart-owned)
  /// list when the attribute is absent.
  static Float32List _float32View(Pointer<Float> pointer, int count) {
    if (pointer == nullptr || count <= 0) {
      return Float32List(0);
    }
    return pointer.asTypedList(count);
  }

  /// Zero-copy view over a native uint32 index buffer, or an empty
  /// (Dart-owned) list when the mesh is non-indexed.
  static Uint32List _uint32View(Pointer<Uint32> pointer, int count) {
    if (pointer == nullptr || count <= 0) {
      return Uint32List(0);
    }
    return pointer.asTypedList(count);
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

// Shared empty lists so callers can omit optional attributes without
// allocating.
final Float32List _emptyFloat32 = Float32List(0);
final Uint32List _emptyUint32 = Uint32List(0);
