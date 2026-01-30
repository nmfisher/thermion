import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/wireframe_geometry.dart';

/// A wrapper that manages both solid and wireframe versions of a glTF asset.
///
/// This class allows toggling between solid and wireframe rendering modes
/// dynamically. Both versions are kept in the scene but only one is visible
/// at a time using layer masks.
///
/// **Limitations:**
/// - Static meshes only (no skinned meshes or morph targets)
/// - Single mesh glTF files only
/// - User must provide wireframe material
///
/// Example:
/// ```dart
/// final wireframeMat = await app.createMaterial(wireframeMaterialData);
/// final wireframeInstance = await wireframeMat.createInstance();
///
/// final renderable = await WireframeRenderable.create(
///   viewer: viewer,
///   gltfData: gltfBytes,
///   wireframeMaterial: wireframeInstance,
/// );
///
/// // Toggle to wireframe
/// await renderable.showWireframe();
///
/// // Toggle back to solid
/// await renderable.showSolid();
///
/// // Clean up
/// await renderable.dispose();
/// ```
class WireframeRenderable {
  final ThermionViewer _viewer;
  final Uint8List? _gltfData;
  final Geometry? _geometry;
  final MaterialInstance _wireframeMaterialInstance;
  final String? _meshName;

  ThermionAsset? _solidAsset;
  ThermionEntity? _wireframeEntity;
  bool _isWireframeVisible = false;
  bool _disposed = false;
  bool _loaded = false;

  WireframeRenderable._({
    required ThermionViewer viewer,
    Uint8List? gltfData,
    Geometry? geometry,
    required MaterialInstance wireframeMaterial,
    String? meshName,
  })  : _viewer = viewer,
        _gltfData = gltfData,
        _geometry = geometry,
        _wireframeMaterialInstance = wireframeMaterial,
        _meshName = meshName {
    if (_gltfData == null && _geometry == null) {
      throw ArgumentError('Either gltfData or geometry must be provided');
    }
  }

  /// Creates and loads a WireframeRenderable.
  ///
  /// This is the recommended way to create a WireframeRenderable as it
  /// ensures proper initialization.
  ///
  /// Parameters:
  /// - [viewer]: The ThermionViewer to use for scene management
  /// - [gltfData]: Raw glTF/glb file bytes
  /// - [wireframeMaterial]: Material instance for wireframe rendering (must use CUSTOM0)
  /// - [meshName]: Optional name of specific mesh to convert
  /// - [initiallyWireframe]: If true, shows wireframe mode initially
  static Future<WireframeRenderable> create({
    required ThermionViewer viewer,
    required Uint8List gltfData,
    required MaterialInstance wireframeMaterial,
    String? meshName,
    bool initiallyWireframe = false,
  }) async {
    final renderable = WireframeRenderable._(
      viewer: viewer,
      gltfData: gltfData,
      wireframeMaterial: wireframeMaterial,
      meshName: meshName,
    );

    await renderable._load();

    if (initiallyWireframe) {
      await renderable.showWireframe();
    }

    return renderable;
  }

  /// Creates and loads a WireframeRenderable from a Geometry object.
  ///
  /// This is the preferred method when using programmatic geometry
  /// (e.g., GeometryHelper.cube()) rather than loading from a glTF file.
  ///
  /// Parameters:
  /// - [viewer]: The ThermionViewer to use for scene management
  /// - [geometry]: The Geometry object (from GeometryHelper, etc.)
  /// - [wireframeMaterial]: Material instance for wireframe rendering (must use UV0)
  /// - [initiallyWireframe]: If true, shows wireframe mode initially
  static Future<WireframeRenderable> createFromGeometry({
    required ThermionViewer viewer,
    required Geometry geometry,
    required MaterialInstance wireframeMaterial,
    bool initiallyWireframe = false,
  }) async {
    final renderable = WireframeRenderable._(
      viewer: viewer,
      geometry: geometry,
      wireframeMaterial: wireframeMaterial,
    );

    await renderable._load();

    if (initiallyWireframe) {
      await renderable.showWireframe();
    }

    return renderable;
  }

  /// Creates a WireframeRenderable from glTF data with automatic material creation.
  ///
  /// This is the simplest way to create a wireframe renderable - it automatically
  /// creates and configures the wireframe material for you.
  ///
  /// Parameters:
  /// - [viewer]: The ThermionViewer to use for scene management
  /// - [gltfData]: Raw glTF/glb file bytes
  /// - [edgeColor]: Optional edge color (default: white)
  /// - [edgeWidth]: Line width in pixels (default: 1.5)
  /// - [meshName]: Optional name of specific mesh to convert
  /// - [initiallyWireframe]: If true, shows wireframe mode initially
  ///
  /// Example:
  /// ```dart
  /// final renderable = await WireframeRenderable.fromGltf(
  ///   viewer: viewer,
  ///   gltfData: gltfBytes,
  ///   edgeColor: LinearColor(0, 1, 0), // green edges
  ///   edgeWidth: 2.0,
  ///   initiallyWireframe: true,
  /// );
  ///
  /// // Later toggle between modes
  /// await renderable.toggle();
  ///
  /// // Clean up
  /// await renderable.dispose();
  /// ```
  static Future<WireframeRenderable> fromGltf({
    required ThermionViewer viewer,
    required Uint8List gltfData,
    LinearColor? edgeColor,
    double edgeWidth = 1.5,
    String? meshName,
    bool initiallyWireframe = false,
  }) async {
    // Create wireframe material instance using centralized helper
    final instance = await FFIWireframeGeometry.createWireframeMaterialInstance(
      edgeColor: edgeColor,
      edgeWidth: edgeWidth,
    );

    return WireframeRenderable.create(
      viewer: viewer,
      gltfData: gltfData,
      wireframeMaterial: instance,
      meshName: meshName,
      initiallyWireframe: initiallyWireframe,
    );
  }

  /// Creates a WireframeRenderable from Geometry with automatic material creation.
  ///
  /// This is the simplest way to create a wireframe renderable from programmatic
  /// geometry - it automatically creates and configures the wireframe material for you.
  ///
  /// Parameters:
  /// - [viewer]: The ThermionViewer to use for scene management
  /// - [geometry]: The Geometry object (from GeometryHelper, etc.)
  /// - [edgeColor]: Optional edge color (default: white)
  /// - [edgeWidth]: Line width in pixels (default: 1.5)
  /// - [initiallyWireframe]: If true, shows wireframe mode initially
  ///
  /// Example:
  /// ```dart
  /// final cube = GeometryHelper.cube();
  /// final renderable = await WireframeRenderable.fromGeometry(
  ///   viewer: viewer,
  ///   geometry: cube,
  ///   edgeColor: LinearColor(1, 0, 0), // red edges
  ///   edgeWidth: 2.0,
  /// );
  ///
  /// // Toggle to wireframe
  /// await renderable.showWireframe();
  /// ```
  static Future<WireframeRenderable> fromGeometry({
    required ThermionViewer viewer,
    required Geometry geometry,
    LinearColor? edgeColor,
    double edgeWidth = 1.5,
    bool initiallyWireframe = false,
  }) async {
    // Create wireframe material instance using centralized helper
    final instance = await FFIWireframeGeometry.createWireframeMaterialInstance(
      edgeColor: edgeColor,
      edgeWidth: edgeWidth,
    );

    return WireframeRenderable.createFromGeometry(
      viewer: viewer,
      geometry: geometry,
      wireframeMaterial: instance,
      initiallyWireframe: initiallyWireframe,
    );
  }

  /// Returns true if wireframe mode is currently visible.
  bool get isWireframeVisible => _isWireframeVisible;

  /// Returns the currently active entity (for picking, raycasting, etc.).
  ///
  /// Returns the wireframe entity if wireframe is visible, otherwise the
  /// solid asset's root entity.
  ThermionEntity get activeEntity {
    if (_disposed) {
      throw StateError('WireframeRenderable has been disposed');
    }
    if (!_loaded) {
      throw StateError('WireframeRenderable has not been loaded');
    }
    return _isWireframeVisible ? _wireframeEntity! : _solidAsset!.entity;
  }

  /// Returns the solid asset (for animation control, material access, etc.).
  ThermionAsset? get solidAsset => _solidAsset;

  /// Returns the wireframe entity.
  ThermionEntity? get wireframeEntity => _wireframeEntity;

  /// Loads both solid and wireframe versions and adds them to the scene.
  Future<void> _load() async {
    if (_loaded) return;

    final app = FilamentApp.instance!;

    final geometry = _geometry;
    final gltfData = _gltfData;

    if (geometry != null) {
      // Create from Geometry object
      _solidAsset = await _viewer.createGeometry(geometry);
      _wireframeEntity = await FFIWireframeGeometry.createFromGeometry(
        app,
        geometry,
        wireframeMaterial: _wireframeMaterialInstance,
      );
    } else if (gltfData != null) {
      // Create from glTF data
      _solidAsset = await app.loadGltfFromBuffer(gltfData);
      _wireframeEntity = await FFIWireframeGeometry.createFromGltf(
        app,
        gltfData,
        meshName: _meshName,
        wireframeMaterial: _wireframeMaterialInstance,
      );
    }

    // Add both to scene
    await _viewer.addToScene(_solidAsset!);

    final scene = await _viewer.view.getScene();
    await scene.addEntity(_wireframeEntity!);

    // Initially hide wireframe
    await _setEntityVisible(_wireframeEntity!, false);

    _loaded = true;
  }

  /// Shows the wireframe version and hides the solid version.
  Future<void> showWireframe() async {
    if (_disposed) {
      throw StateError('WireframeRenderable has been disposed');
    }
    if (!_loaded) {
      throw StateError('WireframeRenderable has not been loaded');
    }

    if (_isWireframeVisible) return;

    await _setAssetVisible(_solidAsset!, false);
    await _setEntityVisible(_wireframeEntity!, true);
    _isWireframeVisible = true;
  }

  /// Shows the solid version and hides the wireframe version.
  Future<void> showSolid() async {
    if (_disposed) {
      throw StateError('WireframeRenderable has been disposed');
    }
    if (!_loaded) {
      throw StateError('WireframeRenderable has not been loaded');
    }

    if (!_isWireframeVisible) return;

    await _setEntityVisible(_wireframeEntity!, false);
    await _setAssetVisible(_solidAsset!, true);
    _isWireframeVisible = false;
  }

  /// Toggles between solid and wireframe modes.
  Future<void> toggle() async {
    if (_isWireframeVisible) {
      await showSolid();
    } else {
      await showWireframe();
    }
  }

  /// Sets the transform for both solid and wireframe versions.
  Future<void> setTransform(Matrix4 transform) async {
    if (_disposed) {
      throw StateError('WireframeRenderable has been disposed');
    }
    if (!_loaded) {
      throw StateError('WireframeRenderable has not been loaded');
    }

    final app = FilamentApp.instance!;

    if (_solidAsset != null) {
      await app.setTransform(_solidAsset!.entity, transform);
    }
    if (_wireframeEntity != null) {
      await app.setTransform(_wireframeEntity!, transform);
    }
  }

  /// Gets the current world transform.
  Future<Matrix4> getWorldTransform() async {
    if (_disposed) {
      throw StateError('WireframeRenderable has been disposed');
    }
    if (!_loaded) {
      throw StateError('WireframeRenderable has not been loaded');
    }

    return FilamentApp.instance!.getWorldTransform(activeEntity);
  }

  /// Disposes of both solid and wireframe versions.
  ///
  /// After calling this method, the WireframeRenderable can no longer be used.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final app = FilamentApp.instance!;
    final scene = await _viewer.view.getScene();

    // Remove and destroy solid asset (use viewer.destroyAsset to remove from tracking)
    if (_solidAsset != null) {
      await _viewer.destroyAsset(_solidAsset!);
      _solidAsset = null;
    }

    // Remove and destroy wireframe entity
    if (_wireframeEntity != null) {
      await scene.removeEntity(_wireframeEntity!);
      await app.destroyEntity(_wireframeEntity!);
      _wireframeEntity = null;
    }
  }

  /// Sets visibility for a single entity using layer masks.
  Future<void> _setEntityVisible(ThermionEntity entity, bool visible) async {
    final renderableManager = FilamentApp.instance!.renderableManager;
    final mask = visible ? 0x01 : 0x00;
    await renderableManager.setLayerMask(entity, 0x01, mask);
  }

  /// Sets visibility for all entities in an asset (root + children).
  ///
  /// glTF assets typically have renderable geometry on child entities,
  /// not the root entity, so we need to set visibility on all of them.
  Future<void> _setAssetVisible(ThermionAsset asset, bool visible) async {
    final renderableManager = FilamentApp.instance!.renderableManager;
    final mask = visible ? 0x01 : 0x00;

    // Set visibility on root entity
    await renderableManager.setLayerMask(asset.entity, 0x01, mask);

    // Set visibility on all child entities
    final children = await asset.getChildEntities();
    for (final child in children) {
      await renderableManager.setLayerMask(child, 0x01, mask);
    }
  }
}
