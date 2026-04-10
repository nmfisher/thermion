import 'package:thermion_dart/thermion_dart.dart';

/// Represents a single mesh from an OBJ file.
class ObjMesh {
  /// Mesh name (from 'o' or 'g' directive in OBJ file)
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

  ObjMesh({
    required this.name,
    required this.materialName,
    required this.vertices,
    required this.normals,
    required this.uvs,
    required this.indices,
  });

  /// Creates a Geometry object from this mesh data.
  Geometry toGeometry({
    bool flipUvs = false,
    bool createDummyColors = true,
    bool createDummyUvs = true,
  }) {
    // Flip UVs if requested (OBJ uses bottom-left origin, Filament uses top-left)
    // Pass null when uvs are empty to allow Geometry constructor to create dummy UVs
    final Float32List? processedUvs = uvs.isEmpty
        ? null
        : (flipUvs ? _flipUVs(uvs) : uvs);

    // Determine index type based on index count
    final indexType = indices.length <= 65535
        ? IndexType.USHORT
        : IndexType.UINT;

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
      result[i] = uvs[i];       // u unchanged
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

/// OBJ file importer using Assimp.
///
/// This class provides methods to load OBJ files from buffers
/// and extract mesh data (vertices, normals, UVs, indices).
///
/// Example usage:
/// ```dart
/// final meshes = ObjImporter.loadFromBuffer(objData);
/// for (final mesh in meshes) {
///   final geometry = mesh.toGeometry(flipUvs: true);
///   final asset = await createGeometry(geometry);
/// }
/// ```
class ObjImporter {
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

  /// Load an OBJ file from a byte buffer.
  ///
  /// Returns a list of [ObjMesh] objects, one for each mesh in the OBJ file.
  /// Throws an exception if the file cannot be loaded.
  static List<ObjMesh> loadFromBuffer(Uint8List data) {
    // Use calloc to allocate native memory for the data pointer
    final dataPointer = calloc<Uint8>(data.length);
    final dataBytes = dataPointer.cast<Uint8>().asTypedList(data.length);
    dataBytes.setAll(0, data);

    try {
      final importerPtr = ObjImporter_loadFromBuffer(dataPointer, data.length);

      if (importerPtr == nullptr) {
        throw Exception('Failed to load OBJ file: Assimp returned null importer');
      }

      try {
        final meshCount = ObjImporter_getMeshCount(importerPtr);

        if (meshCount == 0) {
          throw Exception('Failed to load OBJ file: No meshes found in file');
        }

        final meshes = <ObjMesh>[];

        for (int i = 0; i < meshCount; i++) {
          final mesh = _readMesh(importerPtr, i);
          meshes.add(mesh);
        }

        if (meshes.isEmpty) {
          throw Exception('Failed to load OBJ file: No valid meshes parsed');
        }

        return meshes;
      } finally {
        ObjImporter_destroy(importerPtr);
      }
    } finally {
      calloc.free(dataPointer);
    }
  }

  static ObjMesh _readMesh(Pointer<TObjImporter> importerPtr, int meshIndex) {
    // Get vertices
    final verticesPtrPtr = calloc<Pointer<Float>>();
    final verticesCountPtr = calloc<Int>();
    ObjImporter_getVertices(
      importerPtr,
      meshIndex,
      verticesPtrPtr,
      verticesCountPtr,
    );

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
    ObjImporter_getIndices(
      importerPtr,
      meshIndex,
      indicesPtrPtr,
      indicesCountPtr,
    );

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
    ObjImporter_getNormals(
      importerPtr,
      meshIndex,
      normalsPtrPtr,
      normalsCountPtr,
    );

    final normals = normalsCountPtr.value > 0
        ? Float32List.fromList(
            normalsPtrPtr.value.asTypedList(normalsCountPtr.value),
          )
        : Float32List(0);

    // Free temporary pointers
    calloc.free(normalsPtrPtr);
    calloc.free(normalsCountPtr);

    // Get UVs (optional)
    final uvsPtrPtr = calloc<Pointer<Float>>();
    final uvsCountPtr = calloc<Int>();
    ObjImporter_getUVs(
      importerPtr,
      meshIndex,
      uvsPtrPtr,
      uvsCountPtr,
    );

    final uvs = uvsCountPtr.value > 0
        ? Float32List.fromList(
            uvsPtrPtr.value.asTypedList(uvsCountPtr.value),
          )
        : Float32List(0);

    // Free temporary pointers
    calloc.free(uvsPtrPtr);
    calloc.free(uvsCountPtr);

    // Get material name (optional)
    final materialNamePtr = ObjImporter_getMaterialName(importerPtr, meshIndex);
    final materialName = materialNamePtr != nullptr
        ? _safeDartString(materialNamePtr)
        : null;

    // Get mesh name (optional)
    final meshNamePtr = ObjImporter_getMeshName(importerPtr, meshIndex);
    final meshName = meshNamePtr != nullptr
        ? _safeDartString(meshNamePtr)
        : null;

    return ObjMesh(
      name: meshName,
      materialName: materialName,
      vertices: vertices,
      normals: normals,
      uvs: uvs,
      indices: indices,
    );
  }
}
