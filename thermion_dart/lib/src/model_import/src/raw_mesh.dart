import 'package:thermion_dart/thermion_dart.dart';

/// The single flat-mesh result type shared by every model-file import path
/// (Assimp and cgltf).
///
/// A [RawMesh] is one decomposed mesh of a model file: names plus vertex
/// attributes and indices, with no scene hierarchy. Positions/normals are
/// 3 floats per vertex, UVs are 2 floats per vertex (first channel only).
///
/// All buffers are plain Dart-owned copies; nothing points into native
/// memory after the importer call returns.
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
  /// [flipUvs] flips UV coordinates vertically (v = 1.0 - v) when the source
  /// format uses a bottom-left UV origin (most formats do; Filament uses
  /// top-left). Flipping happens here only, never in native Assimp, so it is
  /// never double-applied.
  Geometry toGeometry({bool flipUvs = false, bool createDummyColors = true, bool createDummyUvs = true}) {
    final Float32List? processedUvs = uvs.isEmpty ? null : (flipUvs ? _flipUVs(uvs) : uvs);

    final indexType = indices.length <= 65535 ? IndexType.USHORT : IndexType.UINT;

    final List<int> convertedIndices;
    if (indexType == IndexType.USHORT) {
      convertedIndices = indices.map((i) => i.toInt()).toList();
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

  /// No-op. Retained for source compatibility with the former
  /// [ImportedMesh.dispose]; buffers are Dart-owned copies.
  void dispose() {}

  static Float32List _flipUVs(Float32List uvs) {
    final result = Float32List(uvs.length);
    for (int i = 0; i < uvs.length; i += 2) {
      result[i] = uvs[i]; // u unchanged
      result[i + 1] = 1.0 - uvs[i + 1]; // v flipped
    }
    return result;
  }
}

// Shared empty lists so callers can omit optional attributes without
// allocating.
final Float32List _emptyFloat32 = Float32List(0);
final Uint32List _emptyUint32 = Uint32List(0);
