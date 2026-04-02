import 'package:thermion_dart/src/filament/src/implementation/ffi_gltf_mesh_data.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';

class FFIWireframeAsset extends FFIAsset {
  static Material? _material;

  FFIWireframeAsset(super.asset);

  static Future<MaterialInstance> _createMaterialInstance({
    LinearColor? edgeColor,
    double edgeWidth = 1.5,
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

    if (edgeColor != null) {
      await instance.setParameterFloat4(
          "edgeColor", edgeColor.r, edgeColor.g, edgeColor.b, 1.0);
    }
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
