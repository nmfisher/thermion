import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_gltf_mesh_data.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/thermion_dart.dart';
import '../../../bindings/bindings.dart' as bindings;

/// FFI implementation of WireframeGeometry for native platforms.
class FFIWireframeGeometry {
  /// Create a wireframe renderable entity from glTF data.
  ///
  /// Returns a new entity with duplicated vertices (so each triangle has unique
  /// vertices) and barycentric coordinates in the custom0 vertex attribute.
  ///
  /// The original glTF asset remains unchanged.
  ///
  /// Note: [wireframeMaterial] must be provided. It should be a material instance
  /// that uses the custom0 vertex attribute for barycentric coordinates.
  static Future<ThermionEntity> createFromGltf(
    FilamentApp app,
    List<int> gltfData, {
    String? meshName,
    MaterialInstance? wireframeMaterial,
  }) async {
    if (wireframeMaterial == null) {
      throw ArgumentError(
        'wireframeMaterial must be provided. Use app.createMaterial() to load '
        'a wireframe material that uses custom0 for barycentric coordinates.',
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

    // Create wireframe geometry with duplicated vertices and barycentrics
    final geometry = duplicateVerticesWithBarycentrics(
      meshData.vertices,
      meshData.indices!,
    );

    // Build vertex buffer with only POSITION and CUSTOM0 attributes
    final vertexBufferBuilder = FFIVertexBufferBuilder(ffiApp.engine);
    vertexBufferBuilder.vertexCount(geometry.vertices.length ~/ 3);
    vertexBufferBuilder.bufferCount(2);

    // Buffer 0: positions (FLOAT3)
    vertexBufferBuilder.attribute(
      VertexAttribute.POSITION,
      0,
      VertexAttributeType.FLOAT3,
      byteOffset: 0,
      byteStride: 12,
    );

    // Buffer 1: custom0 barycentric coords (FLOAT4)
    vertexBufferBuilder.attribute(
      VertexAttribute.CUSTOM0,
      1,
      VertexAttributeType.FLOAT4,
      byteOffset: 0,
      byteStride: 16,
    );

    final vertexBuffer = await vertexBufferBuilder.build() as FFIVertexBuffer;

    // Set position data at buffer 0
    await vertexBuffer.setBufferAt(0, geometry.vertices);

    // Set custom0 data (barycentric coordinates) at buffer 1
    await vertexBuffer.setBufferAt(1, geometry.attribute0);

    // Build index buffer
    final indexBufferBuilder = FFIIndexBufferBuilder(ffiApp.engine);
    indexBufferBuilder.indexCount(geometry.indices.length);
    indexBufferBuilder.bufferType(IndexType.UINT);
    final indexBuffer = await indexBufferBuilder.build() as FFIIndexBuffer;

    final indexTypedData = makeUint32List(geometry.indices.length)
      ..setRange(0, geometry.indices.length, geometry.indices);
    await indexBuffer.setBuffer(indexTypedData);

    // Compute bounding box
    final cAabb = _computeBoundingBoxStruct(geometry.vertices);

    // Create the scene asset from buffers
    final assetPtr = await withPointerCallback<bindings.TSceneAsset>((callback) {
      final ptrList = makeIntPtrList(1);
      ptrList[0] = (wireframeMaterial as FFIMaterialInstance).pointer.address;

      final ptr = SceneAsset_createFromBuffersRenderThread(
        ffiApp.engine,
        vertexBuffer.getNativeHandle(),
        indexBuffer.getNativeHandle(),
        ptrList.address.cast(),
        1,
        PrimitiveType.TRIANGLES.index,
        cAabb,
        callback,
      );

      ptrList.free();
      return ptr;
    });

    if (assetPtr == bindings.nullptr) {
      throw Exception("Failed to create wireframe geometry");
    }

    final asset = FFIAsset(assetPtr);
    return asset.entity;
  }

  /// Duplicate vertices so each triangle has unique vertices,
  /// and add barycentric coordinates to custom0.
  ///
  /// For each triangle (i0, i1, i2):
  /// - Vertex at i0 gets barycentric (1, 0, 0, 0)
  /// - Vertex at i1 gets barycentric (0, 1, 0, 0)
  /// - Vertex at i2 gets barycentric (0, 0, 0, 0)
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
    final newCustom0 = Float32List(newVertexCount * 4);
    final newIndices = Int32List(newVertexCount);

    // Barycentric coordinates for each triangle vertex
    const bary1 = [1.0, 0.0, 0.0, 0.0]; // (1, 0)
    const bary2 = [0.0, 1.0, 0.0, 0.0]; // (0, 1)
    const bary3 = [0.0, 0.0, 0.0, 0.0]; // (0, 0)

    for (int t = 0; t < triangleCount; t++) {
      final i0 = indices[t * 3 + 0];
      final i1 = indices[t * 3 + 1];
      final i2 = indices[t * 3 + 2];

      final outIdx = t * 3;

      // Copy vertex 0 and assign barycentric (1,0,0,0)
      _copyVertex(vertices, i0, newVertices, outIdx + 0);
      _copyBarycentric(bary1, newCustom0, outIdx + 0);
      newIndices[outIdx + 0] = outIdx + 0;

      // Copy vertex 1 and assign barycentric (0,1,0,0)
      _copyVertex(vertices, i1, newVertices, outIdx + 1);
      _copyBarycentric(bary2, newCustom0, outIdx + 1);
      newIndices[outIdx + 1] = outIdx + 1;

      // Copy vertex 2 and assign barycentric (0,0,0,0)
      _copyVertex(vertices, i2, newVertices, outIdx + 2);
      _copyBarycentric(bary3, newCustom0, outIdx + 2);
      newIndices[outIdx + 2] = outIdx + 2;
    }

    return Geometry(
      newVertices,
      newIndices,
      attribute0: newCustom0,
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
    final dstOffset = dstIndex * 4;
    dst[dstOffset + 0] = src[0];
    dst[dstOffset + 1] = src[1];
    dst[dstOffset + 2] = src[2];
    dst[dstOffset + 3] = src[3];
  }

  static bindings.Aabb3 _computeBoundingBoxStruct(Float32List vertices) {
    if (vertices.isEmpty) {
      final cAabb = bindings.StructAllocator.create<bindings.Aabb3>();
      cAabb.centerX = 0;
      cAabb.centerY = 0;
      cAabb.centerZ = 0;
      cAabb.halfExtentX = 0;
      cAabb.halfExtentY = 0;
      cAabb.halfExtentZ = 0;
      return cAabb;
    }

    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = double.negativeInfinity,
        maxY = double.negativeInfinity,
        maxZ = double.negativeInfinity;

    for (int i = 0; i < vertices.length; i += 3) {
      final x = vertices[i];
      final y = vertices[i + 1];
      final z = vertices[i + 2];

      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }

    final cAabb = bindings.StructAllocator.create<bindings.Aabb3>();
    cAabb.centerX = (minX + maxX) / 2.0;
    cAabb.centerY = (minY + maxY) / 2.0;
    cAabb.centerZ = (minZ + maxZ) / 2.0;
    cAabb.halfExtentX = (maxX - minX) / 2.0;
    cAabb.halfExtentY = (maxY - minY) / 2.0;
    cAabb.halfExtentZ = (maxZ - minZ) / 2.0;

    return cAabb;
  }
}
