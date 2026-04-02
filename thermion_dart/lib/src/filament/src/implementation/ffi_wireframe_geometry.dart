import 'package:thermion_dart/src/filament/src/implementation/ffi_gltf_mesh_data.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';

class FFIWireframeAsset extends FFIAsset {
  static Material? _material;

  FFIWireframeAsset(super.asset);

  static Future<MaterialInstance> _createMaterialInstance({
    double edgeR = 0.3,
    double edgeG = 0.3,
    double edgeB = 0.3,
    double edgeA = 0.3,
    double faceR = 0.1,
    double faceG = 0.1,
    double faceB = 0.1,
    double faceA = 0.1,
    double edgeWidth = 0.5,
  }) async {
    // Create wireframe material
    _material ??= FFIMaterial(await withPointerCallback<TMaterial>(
      (callback) => Material_createWireframeMaterialRenderThread(
        FilamentApp.instance!.engine,
        callback,
      ),
    ));

    // Create and configure material instance
    final instance = await _material!.createInstance();

    // Make double-sided to avoid winding/culling issues with extracted geometry
    await instance.setDoubleSided(true);

    await instance.setParameterFloat4("edgeColor", edgeR, edgeG, edgeB, edgeA);
    await instance.setParameterFloat4("faceColor", faceR, faceG, faceB, faceA);
    await instance.setParameterFloat("edgeWidth", edgeWidth);

    return instance;
  }

  static Future<ThermionAsset> fromGeometry(Geometry geometry) async {
    List<int> triangleIndices;
    if (geometry.primitiveType == PrimitiveType.TRIANGLE_STRIP) {
      triangleIndices = GeometryUtils.expandTriangleStrip(geometry.indices);
    } else {
      triangleIndices = geometry.indices;
    }

    if (triangleIndices.isEmpty) {
      throw ArgumentError('Geometry must have indices');
    }

    // Create wireframe geometry with duplicated vertices and barycentrics in
    // CUSTOM0
    final wireframeGeom = GeometryUtils.duplicateVerticesWithBarycentrics(
      geometry.vertices,
      triangleIndices,
    );

    final materialInstance = await _createMaterialInstance();

    // Use createGeometry with the wireframe material
    final asset = await FilamentApp.instance!.createGeometry(
      wireframeGeom,
      materialInstances: [materialInstance],
    );
    return FFIWireframeAsset(asset.getNativeHandle());
  }

  /// Creates a wireframe overlay entity by extracting mesh data from a loaded
  /// glTF asset. The overlay is a separate entity that can be added/removed
  /// from the scene independently.
  ///
  /// All buffer creation happens in C++ using the same enableBufferObjects +
  /// BufferObject pattern as the working applyWireframeBarycentrics.
  static Future<ThermionAsset> createOverlayFromAsset(
    ThermionAsset asset, {
    double edgeR = 0.3,
    double edgeG = 0.3,
    double edgeB = 0.3,
    double edgeA = 0.3,
    double faceR = 0.1,
    double faceG = 0.1,
    double faceB = 0.1,
    double faceA = 0.1,
    double edgeWidth = 0.5,
  }) async {
    final nativeHandle = asset.getNativeHandle();

    // Create wireframe material instance
    final materialInstance = await _createMaterialInstance(
      edgeR: edgeR,
      edgeG: edgeG,
      edgeB: edgeB,
      edgeA: edgeA,
      faceR: faceR,
      faceG: faceG,
      faceB: faceB,
      faceA: faceA,
      edgeWidth: edgeWidth,
    );

    // Delegate everything to C++ — extract mesh data, unweld, assign
    // barycentrics, build VertexBuffer/IndexBuffer, create GeometrySceneAsset.
    final assetPtr = await withPointerCallback<TSceneAsset>((callback) {
      SceneAsset_createWireframeOverlayRenderThread(
          nativeHandle, materialInstance.getNativeHandle(), callback);
    });

    if (assetPtr == nullptr) {
      throw Exception('Failed to create wireframe overlay');
    }

    return FFIWireframeAsset(assetPtr);
  }

  static Future<ThermionAsset> createFromGltf(Uint8List gltfData) async {
    // Parse glTF to extract vertex and index data
    final meshData = await FFIGltfMeshData.parse(
      gltfData,
    );

    if (meshData.indices == null) {
      throw ArgumentError('glTF must have indexed geometry');
    }

    // Convert triangle strip indices to triangle list if needed
    List<int> triangleIndices;
    if (meshData.primitiveType == PrimitiveType.TRIANGLE_STRIP) {
      triangleIndices = GeometryUtils.expandTriangleStrip(meshData.indices!);
    } else {
      triangleIndices = meshData.indices!;
    }

    // Create wireframe geometry with duplicated vertices and barycentrics in
    // CUSTOM0
    final wireframeGeom = GeometryUtils.duplicateVerticesWithBarycentrics(
      meshData.vertices,
      triangleIndices,
    );

    final materialInstance = await _createMaterialInstance();

    final asset = await FilamentApp.instance!.createGeometry(
      wireframeGeom,
      materialInstances: [materialInstance],
    );
    return FFIWireframeAsset(asset.getNativeHandle());
  }
}
