import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_gltf_mesh_data.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of WireframeGeometry for native platforms.
class FFIWireframeGeometry {
  /// Creates a wireframe material instance with optional configuration.
  ///
  /// This is a convenience method that creates the wireframe material and
  /// configures it with the specified color and edge width.
  ///
  /// Parameters:
  /// - [edgeColor]: Optional edge color (default: white)
  /// - [edgeWidth]: Line width in pixels (default: 1.5)
  ///
  /// Returns a configured [MaterialInstance] ready to use.
  static Future<MaterialInstance> createWireframeMaterialInstance({
    LinearColor? edgeColor,
    double edgeWidth = 1.5,
  }) async {
    // Create wireframe material
    final material = FFIMaterial(await withPointerCallback<TMaterial>(
      (callback) => Material_createWireframeMaterialRenderThread(
        FilamentApp.instance!.engine,
        callback,
      ),
    ));

    // Create and configure material instance
    final instance = await material.createInstance();

    if (edgeColor != null) {
      await instance.setParameterFloat4("edgeColor", edgeColor.r, edgeColor.g, edgeColor.b, 1.0);
    }
    await instance.setParameterFloat("edgeWidth", edgeWidth);

    return instance;
  }
  /// Create a wireframe renderable entity from a Geometry object.
  ///
  /// This is the preferred method when you have programmatic geometry
  /// (from GeometryHelper, etc.) rather than a glTF file.
  ///
  /// Returns a new entity with duplicated vertices (so each triangle has unique
  /// vertices) and barycentric coordinates in the CUSTOM0 vertex attribute.
  static Future<ThermionEntity> createFromGeometry(
    FilamentApp app,
    Geometry geometry, {
    required MaterialInstance wireframeMaterial,
  }) async {
    final ffiApp = app as FFIFilamentApp;

    // Get indices as List<int>
    List<int> triangleIndices;
    if (geometry.primitiveType == PrimitiveType.TRIANGLE_STRIP) {
      triangleIndices = _expandTriangleStrip(geometry.indices);
    } else {
      triangleIndices = geometry.indices;
    }

    if (triangleIndices.isEmpty) {
      throw ArgumentError('Geometry must have indices');
    }

    // Create wireframe geometry with duplicated vertices and barycentrics in CUSTOM0
    final wireframeGeom = duplicateVerticesWithBarycentrics(
      geometry.vertices,
      triangleIndices,
    );

    // Use createGeometry with the wireframe material
    final asset = await ffiApp.createGeometry(
      wireframeGeom,
      materialInstances: [wireframeMaterial],
    );
    return asset.entity;
  }

  /// Create a wireframe renderable entity from glTF data.
  ///
  /// Returns a new entity with duplicated vertices (so each triangle has unique
  /// vertices) and barycentric coordinates in the CUSTOM0 vertex attribute.
  ///
  /// The original glTF asset remains unchanged.
  ///
  /// Note: [wireframeMaterial] must be provided. It should be a material instance
  /// that uses the CUSTOM0 vertex attribute for barycentric coordinates.
  static Future<ThermionEntity> createFromGltf(
    FilamentApp app,
    List<int> gltfData, {
    String? meshName,
    MaterialInstance? wireframeMaterial,
  }) async {
    if (wireframeMaterial == null) {
      throw ArgumentError(
        'wireframeMaterial must be provided. Use app.createMaterial() to load '
        'a wireframe material that uses CUSTOM0 for barycentric coordinates.',
      );
    }

    final ffiApp = app as FFIFilamentApp;

    // Parse glTF to extract vertex and index data
    final meshData = await FFIGltfMeshData.parse(
      Uint8List.fromList(gltfData),
      meshName: meshName,
    );

    if (meshData.indices == null) {
      throw ArgumentError('glTF must have indexed geometry');
    }

    // Convert triangle strip indices to triangle list if needed
    List<int> triangleIndices;
    if (meshData.primitiveType == PrimitiveType.TRIANGLE_STRIP) {
      triangleIndices = _expandTriangleStrip(meshData.indices!);
    } else {
      triangleIndices = meshData.indices!;
    }

    // Create wireframe geometry with duplicated vertices and barycentrics in CUSTOM0
    final wireframeGeom = duplicateVerticesWithBarycentrics(
      meshData.vertices,
      triangleIndices,
    );

    // Use createGeometry with the wireframe material
    final asset = await ffiApp.createGeometry(
      wireframeGeom,
      materialInstances: [wireframeMaterial],
    );
    return asset.entity;
  }

  /// Duplicate vertices so each triangle has unique vertices,
  /// and add barycentric coordinates to CUSTOM0 (attribute0).
  ///
  /// For each triangle (i0, i1, i2):
  /// - Vertex at i0 gets barycentric (1, 0, 0, 0)
  /// - Vertex at i1 gets barycentric (0, 1, 0, 0)
  /// - Vertex at i2 gets barycentric (0, 0, 1, 0)
  ///
  /// Returns a new Geometry with duplicated vertices and sequential indices.
  static Geometry duplicateVerticesWithBarycentrics(
    Float32List vertices,
    List<int> indices,
  ) {
    if (indices.isEmpty) {
      throw ArgumentError('Indices list cannot be empty');
    }
    if (indices.length % 3 != 0) {
      throw ArgumentError('Indices count must be a multiple of 3 (triangles)');
    }

    final triangleCount = indices.length ~/ 3;
    final newVertexCount = triangleCount * 3;
    final newVertices = Float32List(newVertexCount * 3);
    final newBarycentrics = Float32List(newVertexCount * 4);  // CUSTOM0 is FLOAT4
    final newIndices = Int32List(newVertexCount);

    // Barycentric coordinates for each triangle vertex (4 components for FLOAT4)
    const bary1 = [1.0, 0.0, 0.0, 0.0]; // vertex 0
    const bary2 = [0.0, 1.0, 0.0, 0.0]; // vertex 1
    const bary3 = [0.0, 0.0, 1.0, 0.0]; // vertex 2

    for (int t = 0; t < triangleCount; t++) {
      final i0 = indices[t * 3 + 0];
      final i1 = indices[t * 3 + 1];
      final i2 = indices[t * 3 + 2];

      final outIdx = t * 3;

      // Copy vertex 0 and assign barycentric (1, 0, 0)
      _copyVertex(vertices, i0, newVertices, outIdx + 0);
      _copyBarycentric(bary1, newBarycentrics, outIdx + 0);
      newIndices[outIdx + 0] = outIdx + 0;

      // Copy vertex 1 and assign barycentric (0, 1, 0)
      _copyVertex(vertices, i1, newVertices, outIdx + 1);
      _copyBarycentric(bary2, newBarycentrics, outIdx + 1);
      newIndices[outIdx + 1] = outIdx + 1;

      // Copy vertex 2 and assign barycentric (0, 0, 1)
      _copyVertex(vertices, i2, newVertices, outIdx + 2);
      _copyBarycentric(bary3, newBarycentrics, outIdx + 2);
      newIndices[outIdx + 2] = outIdx + 2;
    }

    return Geometry(
      newVertices,
      newIndices,
      attribute0: newBarycentrics,
      primitiveType: PrimitiveType.TRIANGLES,
      indexType: IndexType.UINT,
      createDummyColors: false,
      createDummyUvs: false,
    );
  }

  static void _copyVertex(
    Float32List src,
    int srcIndex,
    Float32List dst,
    int dstIndex,
  ) {
    final srcOffset = srcIndex * 3;
    final dstOffset = dstIndex * 3;
    dst[dstOffset + 0] = src[srcOffset + 0];
    dst[dstOffset + 1] = src[srcOffset + 1];
    dst[dstOffset + 2] = src[srcOffset + 2];
  }

  static void _copyBarycentric(
    List<double> src,
    Float32List dst,
    int dstIndex,
  ) {
    final dstOffset = dstIndex * 4;  // FLOAT4
    dst[dstOffset + 0] = src[0];
    dst[dstOffset + 1] = src[1];
    dst[dstOffset + 2] = src[2];
    dst[dstOffset + 3] = src[3];
  }

  /// Expand triangle strip indices to triangle list indices.
  ///
  /// OpenGL/glTF triangle strip convention:
  /// - Triangle i (even): v[i], v[i+1], v[i+2]
  /// - Triangle i (odd):  v[i+1], v[i], v[i+2]
  ///
  /// This maintains consistent front-face winding (CCW).
  static List<int> _expandTriangleStrip(List<int> stripIndices) {
    if (stripIndices.length < 3) {
      return [];
    }

    final numTriangles = stripIndices.length - 2;
    final triangleIndices = <int>[];

    for (int i = 0; i < numTriangles; i++) {
      final i0 = stripIndices[i];
      final i1 = stripIndices[i + 1];
      final i2 = stripIndices[i + 2];

      // OpenGL triangle strip winding convention
      if (i % 2 == 0) {
        // Even triangles: v[i], v[i+1], v[i+2]
        triangleIndices.add(i0);
        triangleIndices.add(i1);
        triangleIndices.add(i2);
      } else {
        // Odd triangles: v[i+1], v[i], v[i+2]
        triangleIndices.add(i1);
        triangleIndices.add(i0);
        triangleIndices.add(i2);
      }
    }

    return triangleIndices;
  }
}
