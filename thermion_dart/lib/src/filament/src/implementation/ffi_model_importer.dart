import 'package:thermion_dart/thermion_dart.dart';

/// Represents a single mesh parsed from a model file (OBJ/FBX/glTF/STL/PLY/...).
class ImportedMesh {
  /// Mesh/object name
  final String? name;

  /// Material name (from 'usemtl' directive)
  final String? materialName;

  /// Vertex positions (3 floats per vertex: x, y, z)
  final Float32List vertices;

  /// Vertex normals (3 floats per normal: nx, ny, nz)
  /// May be empty if the mesh has no normals
  final Float32List normals;

  /// Texture coordinates (2 floats per UV: u, v)
  /// May be empty if the mesh has no UVs
  final Float32List uvs;

  /// Triangle indices
  final Uint32List indices;

  ImportedMesh({
    required this.name,
    required this.materialName,
    required this.vertices,
    required this.normals,
    required this.uvs,
    required this.indices,
  });

  /// Creates a Geometry object from this mesh data.
  Geometry toGeometry({bool flipUvs = false, bool createDummyColors = true, bool createDummyUvs = true}) {
    // Flip UVs if requested (most model formats use bottom-left origin, Filament top-left)
    // Pass null when uvs are empty to allow Geometry constructor to create dummy UVs
    final Float32List? processedUvs = uvs.isEmpty ? null : (flipUvs ? _flipUVs(uvs) : uvs);

    // Determine index type based on index count
    final indexType = indices.length <= 65535 ? IndexType.USHORT : IndexType.UINT;

    // Convert indices to appropriate type
    final List<int> convertedIndices;
    if (indexType == IndexType.USHORT) {
      convertedIndices = indices.map((i) => i.toInt()).toList();
    } else {
      convertedIndices = indices;
    }

    return Geometry(
      vertices,
      convertedIndices,
      normals: normals.isEmpty ? null : normals,
      uvs: processedUvs,
      indexType: indexType,
      createDummyColors: createDummyColors,
      createDummyUvs: createDummyUvs,
    );
  }

  /// Flips UV coordinates vertically (v = 1.0 - v)
  static Float32List _flipUVs(Float32List uvs) {
    final result = Float32List(uvs.length);
    for (int i = 0; i < uvs.length; i += 2) {
      result[i] = uvs[i]; // u unchanged
      result[i + 1] = 1.0 - uvs[i + 1]; // v flipped
    }
    return result;
  }

  /// Releases native resources associated with this mesh.
  void dispose() {
    vertices.free();
    if (normals.isNotEmpty) normals.free();
    if (uvs.isNotEmpty) uvs.free();
    indices.free();
  }
}

/// Model importer backed by Assimp.
///
/// Supports any format Assimp can read (OBJ, FBX, glTF/glb, STL, PLY, ...).
/// The format is selected via the [formatHint] (file extension without the dot)
/// passed to [loadFromBuffer], since Assimp needs a hint when reading from
/// memory rather than a file path.
///
/// Example usage:
/// ```dart
/// final meshes = ModelImporter.loadFromBuffer(modelData, formatHint: 'fbx');
/// for (final mesh in meshes) {
///   final geometry = mesh.toGeometry(flipUvs: true);
///   final asset = await createGeometry(geometry);
/// }
/// ```
class ModelImporter {
  /// Whether Assimp model loading was compiled into this build.
  ///
  /// Disabled by default; enable at build time with `THERMION_ASSIMP=1` (see
  /// [loadFromBuffer]). When false, [loadFromBuffer] throws [UnsupportedError].
  static bool get isSupported => ModelImporter_isSupported();

  /// Safely convert a C string pointer to a Dart string, handling UTF-8 errors.
  static String? _safeDartString(Pointer<Char> ptr) {
    if (ptr == nullptr) return null;
    try {
      return ptr.cast<Utf8>().toDartString();
    } catch (e) {
      // If UTF-8 conversion fails, return null
      return null;
    }
  }

  /// Load a model from a byte buffer using Assimp.
  ///
  /// [formatHint] is the file extension *without* the dot (e.g. "obj", "fbx",
  /// "glb", "stl", "ply"). Assimp uses it to select the right importer when
  /// reading from memory.
  ///
  /// Returns a list of [ImportedMesh] objects, one for each mesh in the file.
  /// Throws an exception if the file cannot be loaded.
  static List<ImportedMesh> loadFromBuffer(Uint8List data, {required String formatHint}) {
    if (!ModelImporter_isSupported()) {
      throw UnsupportedError(
        'Assimp model loading is not compiled into this build. Rebuild the '
        'native library with the Assimp feature enabled (set THERMION_ASSIMP=1 '
        'when running the platform build script, and add `assimp: true` under '
        'hooks.user_defines.thermion_dart in your pubspec.yaml).',
      );
    }

    // Use calloc to allocate native memory for the data pointer
    final dataPointer = calloc<Uint8>(data.length);
    final dataBytes = dataPointer.cast<Uint8>().asTypedList(data.length);
    dataBytes.setAll(0, data);

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

        final meshes = <ImportedMesh>[];

        for (int i = 0; i < meshCount; i++) {
          final mesh = _readMesh(importerPtr, i);
          meshes.add(mesh);
        }

        if (meshes.isEmpty) {
          throw Exception('Failed to load model ($formatHint): No valid meshes parsed');
        }

        return meshes;
      } finally {
        ModelImporter_destroy(importerPtr);
      }
    } finally {
      calloc.free(dataPointer);
      calloc.free(hintPointer);
    }
  }

  static ImportedMesh _readMesh(Pointer<TModelImporter> importerPtr, int meshIndex) {
    // Get vertices
    final verticesPtrPtr = calloc<Pointer<Float>>();
    final verticesCountPtr = calloc<Int>();
    ModelImporter_getVertices(importerPtr, meshIndex, verticesPtrPtr, verticesCountPtr);

    if (verticesCountPtr.value == 0) {
      calloc.free(verticesPtrPtr);
      calloc.free(verticesCountPtr);
      throw Exception('Mesh $meshIndex has no vertices');
    }

    final verticesCount = verticesCountPtr.value;
    final verticesData = verticesPtrPtr.value.asTypedList(verticesCount);
    final vertices = Float32List.fromList(verticesData);

    // Free temporary pointers
    calloc.free(verticesPtrPtr);
    calloc.free(verticesCountPtr);

    // Get indices
    final indicesPtrPtr = calloc<Pointer<Uint32>>();
    final indicesCountPtr = calloc<Int>();
    ModelImporter_getIndices(importerPtr, meshIndex, indicesPtrPtr, indicesCountPtr);

    if (indicesCountPtr.value == 0) {
      calloc.free(indicesPtrPtr);
      calloc.free(indicesCountPtr);
      throw Exception('Mesh $meshIndex has no indices');
    }

    final indicesCount = indicesCountPtr.value;
    final indicesData = indicesPtrPtr.value.asTypedList(indicesCount);
    final indices = Uint32List.fromList(indicesData);

    // Free temporary pointers
    calloc.free(indicesPtrPtr);
    calloc.free(indicesCountPtr);

    // Get normals (optional)
    final normalsPtrPtr = calloc<Pointer<Float>>();
    final normalsCountPtr = calloc<Int>();
    ModelImporter_getNormals(importerPtr, meshIndex, normalsPtrPtr, normalsCountPtr);

    final normals = normalsCountPtr.value > 0
        ? Float32List.fromList(normalsPtrPtr.value.asTypedList(normalsCountPtr.value))
        : Float32List(0);

    // Free temporary pointers
    calloc.free(normalsPtrPtr);
    calloc.free(normalsCountPtr);

    // Get UVs (optional)
    final uvsPtrPtr = calloc<Pointer<Float>>();
    final uvsCountPtr = calloc<Int>();
    ModelImporter_getUVs(importerPtr, meshIndex, uvsPtrPtr, uvsCountPtr);

    final uvs = uvsCountPtr.value > 0
        ? Float32List.fromList(uvsPtrPtr.value.asTypedList(uvsCountPtr.value))
        : Float32List(0);

    // Free temporary pointers
    calloc.free(uvsPtrPtr);
    calloc.free(uvsCountPtr);

    // Get material name (optional)
    final materialNamePtr = ModelImporter_getMaterialName(importerPtr, meshIndex);
    final materialName = materialNamePtr != nullptr ? _safeDartString(materialNamePtr) : null;

    // Get mesh name (optional)
    final meshNamePtr = ModelImporter_getMeshName(importerPtr, meshIndex);
    final meshName = meshNamePtr != nullptr ? _safeDartString(meshNamePtr) : null;

    return ImportedMesh(
      name: meshName,
      materialName: materialName,
      vertices: vertices,
      normals: normals,
      uvs: uvs,
      indices: indices,
    );
  }
}
