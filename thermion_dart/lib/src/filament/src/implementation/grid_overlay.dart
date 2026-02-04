import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/interface/defaults.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Represents a single LOD level of the grid overlay.
class _GridLevel {
  final ThermionEntity entity;
  final MaterialInstance materialInstance;

  _GridLevel({
    required this.entity,
    required this.materialInstance,
  });
}

/// A grid overlay that displays a 3D grid in the XZ plane.
///
/// The grid consists of 3 LOD levels with different spacing/intervals,
/// which fade in and out based on camera distance to provide infinite
/// grid appearance.
class GridOverlay {
  final List<_GridLevel> _levels;
  final VertexBuffer _vertexBuffer;
  final IndexBuffer _indexBuffer;

  GridOverlay._({
    required List<_GridLevel> levels,
    required VertexBuffer vertexBuffer,
    required IndexBuffer indexBuffer,
  })  : _levels = levels,
        _vertexBuffer = vertexBuffer,
        _indexBuffer = indexBuffer;

  static GridOverlay? _instance;
  static Material? _gridMaterial;
  static List<LinearColor> _currentAxisColors = kDefaultAxisColors;

  /// The entities for each LOD level.
  List<ThermionEntity> get entities => _levels.map((l) => l.entity).toList();

  /// The current axis colors being used by the grid.
  List<LinearColor> get axisColors => _currentAxisColors;

  /// Generates grid geometry: 8x8 quads in the XZ plane at Y=0.
  ///
  /// Returns a tuple of (positions, indices).
  /// - Positions: 256 vertices × 3 floats = 768 floats
  /// - Indices: 8×8 quads × 6 indices = 384 indices
  static (Float32List, Uint32List) _generateGridGeometry() {
    const stepSize = 0.25;
    const gridSize = 8; // Number of cells in each direction
    const vertexCount = gridSize * gridSize * 4; // 4 vertices per quad
    const indexCount = gridSize * gridSize * 6; // 6 indices per quad (2 triangles)

    final positions = Float32List(vertexCount * 3);
    final indices = Uint32List(indexCount);

    int v = 0;
    int idx = 0;

    for (double x = -1.0; x < 1.0; x += stepSize) {
      for (double z = -1.0; z < 1.0; z += stepSize) {
        final baseIndex = v ~/ 3;

        // Add 4 vertices for this quad
        // Bottom-left
        positions[v++] = x;
        positions[v++] = 0.0;
        positions[v++] = z;

        // Top-left
        positions[v++] = x;
        positions[v++] = 0.0;
        positions[v++] = z + stepSize;

        // Top-right
        positions[v++] = x + stepSize;
        positions[v++] = 0.0;
        positions[v++] = z + stepSize;

        // Bottom-right
        positions[v++] = x + stepSize;
        positions[v++] = 0.0;
        positions[v++] = z;

        // Add 6 indices for 2 triangles
        indices[idx++] = baseIndex;
        indices[idx++] = baseIndex + 1;
        indices[idx++] = baseIndex + 2;

        indices[idx++] = baseIndex + 2;
        indices[idx++] = baseIndex + 3;
        indices[idx++] = baseIndex;
      }
    }

    return (positions, indices);
  }

  /// Adds all grid levels to the scene.
  Future addToScene(Scene scene) async {
    for (final level in _levels) {
      await scene.addEntity(level.entity);
    }
  }

  /// Removes all grid levels from the scene.
  Future removeFromScene(Scene scene) async {
    for (final level in _levels) {
      await scene.removeEntity(level.entity);
    }
  }

  /// Destroys all resources held by this grid overlay.
  Future destroy() async {
    for (final level in _levels) {
      await FilamentApp.instance!.destroyEntity(level.entity);
      await level.materialInstance.destroy();
    }
    await _vertexBuffer.destroy();
    await _indexBuffer.destroy();
    // Note: _gridMaterial is shared and kept alive for potential reuse
    _instance = null;
  }

  /// Creates a new grid overlay with the specified parameters.
  ///
  /// Only one instance can exist at a time. Subsequent calls return the existing instance.
  ///
  /// Parameters:
  /// - [axisColors]: Colors for X, Y, Z axes (default: red, green, blue)
  /// - [gridColor]: Base color of the grid lines
  /// - [spacing]: Interval between grid lines for each LOD level
  /// - [fadeInStart]/[fadeInEnd]: Camera distances where each level fades in
  /// - [fadeOutStart]/[fadeOutEnd]: Camera distances where each level fades out
  static Future<GridOverlay> create({
    List<LinearColor> axisColors = kDefaultAxisColors,
    LinearColor gridColor = kDefaultGridColor,
    List<double> spacing = const [1.0, 10.0, 100.0],
    List<double> fadeInStart = const [0.001, 5.0, 50.0],
    List<double> fadeInEnd = const [0.001, 50.0, 500.0],
    List<double> fadeOutStart = const [10.0, 500.0, 5000.0],
    List<double> fadeOutEnd = const [200.0, 2000.0, 20000.0],
  }) async {
    if (_instance != null) {
      return _instance!;
    }

    final app = FilamentApp.instance!;
    final rm = app.renderableManager;

    // Create or reuse the grid material
    _gridMaterial ??= FFIMaterial(Material_createGridMaterial(app.engine));

    // Generate shared geometry
    final (positions, indices) = _generateGridGeometry();

    // Create vertex buffer
    final vbBuilder = rm.createVertexBufferBuilder();
    vbBuilder.vertexCount(positions.length ~/ 3);
    vbBuilder.bufferCount(1);
    vbBuilder.attribute(
      VertexAttribute.POSITION,
      0,
      VertexAttributeType.FLOAT3,
      byteOffset: 0,
      byteStride: 12, // 3 floats × 4 bytes
    );
    final vertexBuffer = await vbBuilder.build();
    await vertexBuffer.setBufferAt(0, positions);

    // Create index buffer
    final ibBuilder = rm.createIndexBufferBuilder();
    ibBuilder.indexCount(indices.length);
    ibBuilder.bufferType(IndexType.UINT);
    final indexBuffer = await ibBuilder.build();
    await indexBuffer.setBuffer(indices);

    // Create the 3 LOD levels
    final levels = <_GridLevel>[];

    for (int i = 0; i < 3; i++) {
      // Create entity
      final entity = await app.createEntity();

      // Create material instance
      final materialInstance = await _gridMaterial!.createInstance();

      // Configure material parameters
      await materialInstance.setParameterFloat3(
          'gridColor', gridColor.r, gridColor.g, gridColor.b);
      await materialInstance.setParameterFloat3(
          'axisColorX', axisColors[0].r, axisColors[0].g, axisColors[0].b);
      await materialInstance.setParameterFloat3(
          'axisColorY', axisColors[1].r, axisColors[1].g, axisColors[1].b);
      await materialInstance.setParameterFloat3(
          'axisColorZ', axisColors[2].r, axisColors[2].g, axisColors[2].b);
      await materialInstance.setParameterFloat('distance', 10000.0);
      await materialInstance.setParameterFloat('interval', spacing[i]);
      await materialInstance.setParameterFloat('fadeInStart', fadeInStart[i]);
      await materialInstance.setParameterFloat('fadeInEnd', fadeInEnd[i]);
      await materialInstance.setParameterFloat('fadeOutStart', fadeOutStart[i]);
      await materialInstance.setParameterFloat('fadeOutEnd', fadeOutEnd[i]);

      // Show axis lines only on the largest grid (index 2)
      if (i == 2) {
        await materialInstance.setParameterBool('showAxisX', true);
        await materialInstance.setParameterBool('showAxisZ', true);
      }

      // Set transparency and culling modes
      await materialInstance
          .setTransparencyMode(TransparencyMode.TWO_PASSES_TWO_SIDES);
      await materialInstance.setCullingMode(CullingMode.NONE);

      // Build the renderable
      final builder = rm.createBuilder(1);
      builder.boundingBox(Aabb3.minMax(
        Vector3(-1.0, -1.0, -1.0),
        Vector3(1.0, 1.0, 1.0),
      ));
      builder.geometry(
        0,
        PrimitiveType.TRIANGLES,
        vertexBuffer,
        indexBuffer,
        0,
        indices.length,
      );
      builder.material(0, materialInstance);
      builder.priority(6);
      // Layer mask: 0xFF select, 1 << 7 (Overlay layer) value
      builder.layerMask(0xFF, 1 << 7);
      // Disable culling - the shader calculates world-space coordinates
      builder.culling(false);
      builder.receiveShadows(false);
      builder.castShadows(false);
      await builder.build(entity);

      levels.add(_GridLevel(
        entity: entity,
        materialInstance: materialInstance,
      ));
    }

    _currentAxisColors = axisColors;
    _instance = GridOverlay._(
      levels: levels,
      vertexBuffer: vertexBuffer,
      indexBuffer: indexBuffer,
    );

    return _instance!;
  }

  /// Sets the axis colors for the grid overlay.
  ///
  /// [axisColors] should be a list of exactly 3 LinearColor objects: [X-axis, Y-axis, Z-axis]
  Future<void> setAxisColor(List<LinearColor> axisColors) async {
    if (axisColors.length != 3) {
      throw ArgumentError(
          'axisColors must contain exactly 3 colors for X, Y, and Z axes');
    }

    _currentAxisColors = axisColors;

    // Update all levels' material instances
    for (final level in _levels) {
      await level.materialInstance.setParameterFloat3(
          'axisColorX', axisColors[0].r, axisColors[0].g, axisColors[0].b);
      await level.materialInstance.setParameterFloat3(
          'axisColorY', axisColors[1].r, axisColors[1].g, axisColors[1].b);
      await level.materialInstance.setParameterFloat3(
          'axisColorZ', axisColors[2].r, axisColors[2].g, axisColors[2].b);
    }
  }

  /// Creating instances is not supported for grid overlays.
  Future<GridOverlay> createInstance(
      {List<MaterialInstance>? materialInstances}) async {
    throw Exception(
        'Only a single instance of the grid overlay can be created');
  }
}
