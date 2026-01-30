import 'package:thermion_dart/thermion_dart.dart';

import '../implementation/wireframe_geometry.dart';

/// Utility class for creating wireframe geometry from glTF models.
///
/// Wireframe rendering requires barycentric coordinates per triangle corner,
/// which means vertices cannot be shared between triangles. This class provides
/// methods to convert indexed geometry to non-indexed geometry with barycentric
/// coordinates.
class WireframeGeometry {
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
  ///
  /// Example:
  /// ```dart
  /// final material = await WireframeGeometry.createWireframeMaterialInstance(
  ///   edgeColor: LinearColor(0, 1, 0), // green
  ///   edgeWidth: 2.0,
  /// );
  /// ```
  static Future<MaterialInstance> createWireframeMaterialInstance({
    LinearColor? edgeColor,
    double edgeWidth = 1.5,
  }) {
    return FFIWireframeGeometry.createWireframeMaterialInstance(
      edgeColor: edgeColor,
      edgeWidth: edgeWidth,
    );
  }

  /// Create a wireframe renderable entity from glTF data.
  ///
  /// Returns a new entity with duplicated vertices (so each triangle has unique
  /// vertices) and barycentric coordinates in the custom0 vertex attribute.
  ///
  /// The original glTF asset remains unchanged.
  ///
  /// Parameters:
  /// - [app]: The FilamentApp instance
  /// - [gltfData]: Raw glTF file data
  /// - [meshName]: Optional name of specific mesh to convert (null = all meshes)
  /// - [wireframeMaterial]: Optional material instance to use (must be provided)
  static Future<ThermionEntity> createFromGltf(
    FilamentApp app,
    List<int> gltfData, {
    String? meshName,
    MaterialInstance? wireframeMaterial,
  }) {
    return FFIWireframeGeometry.createFromGltf(
      app,
      gltfData,
      meshName: meshName,
      wireframeMaterial: wireframeMaterial,
    );
  }

  /// Duplicate vertices so each triangle has unique vertices,
  /// and add barycentric coordinates to custom0.
  ///
  /// This is a lower-level method that works with raw geometry data.
  /// Use [createFromGltf] for a higher-level API that handles glTF parsing.
  static Geometry duplicateVerticesWithBarycentrics(
    Float32List vertices,
    List<int> indices,
  ) {
    return FFIWireframeGeometry.duplicateVerticesWithBarycentrics(
      vertices,
      indices,
    );
  }
}
