import 'package:thermion_dart/thermion_dart.dart';

/// Controller for a bone visualization created by [ThermionViewer.createBoneVisualization].
///
/// Use [update()] to refresh the visualization after bone transforms change.
/// Use [dispose()] to remove the visualization from the scene and free resources.
class BoneVisualizationController {
  final ThermionViewer viewer;
  final ThermionAsset asset;
  final int skinIndex;
  final List<ThermionAsset> _visualizationAssets;
  final List<ThermionEntity> _boneEntities;
  final List<int> _boneParentIndices;
  final double sphereRadius;
  final double cylinderRadius;

  bool _isVisible = true;

  BoneVisualizationController({
    required this.viewer,
    required this.asset,
    required this.skinIndex,
    required List<ThermionAsset> visualizationAssets,
    required List<ThermionEntity> boneEntities,
    required List<int> boneParentIndices,
    required this.sphereRadius,
    required this.cylinderRadius,
  })  : _visualizationAssets = visualizationAssets,
        _boneEntities = boneEntities,
        _boneParentIndices = boneParentIndices;

  /// Whether the visualization is currently visible.
  bool get isVisible => _isVisible;

  /// Update visualization positions to match current bone transforms.
  ///
  /// Call this after modifying bone transforms to update the visualization.
  Future<void> update() async {
    if (!_isVisible) return;

    final tm = FilamentApp.instance!.transformManager;

    for (int i = 0; i < _boneEntities.length; i++) {
      final boneEntity = _boneEntities[i];
      final vizAsset = _visualizationAssets[i];

      // Get current bone position
      final transform = await tm.getWorldTransform(boneEntity);
      final position = transform.getTranslation();

      // Update joint sphere position
      await vizAsset.setTransform(Matrix4.compose(
        position,
        Quaternion.identity(),
        Vector3.all(sphereRadius),
      ));

      // Update cylinder if this bone has a parent
      final parentIndex = _boneParentIndices[i];
      if (parentIndex >= 0 && parentIndex < _boneEntities.length) {
        final cylinderAsset = _visualizationAssets[_boneEntities.length + i];
        final parentEntity = _boneEntities[parentIndex];
        final parentTransform = await tm.getWorldTransform(parentEntity);
        final parentPos = parentTransform.getTranslation();
        await _setCylinderTransform(cylinderAsset, parentPos, position);
      }
    }
  }

  /// Remove visualization from scene and dispose resources.
  Future<void> dispose() async {
    if (!_isVisible) return;

    for (final vizAsset in _visualizationAssets) {
      await viewer.removeFromScene(vizAsset);
      await viewer.destroyAsset(vizAsset);
    }
    _isVisible = false;
  }

  Future<void> _setCylinderTransform(
      ThermionAsset cylinder, Vector3 from, Vector3 to) async {
    final direction = (to - from).normalized();
    final distance = from.distanceTo(to);
    final midpoint = (from + to) / 2;

    // Align cylinder (which points up Y) with direction
    final rotation = Quaternion.fromTwoVectors(Vector3(0, 1, 0), direction);

    await cylinder.setTransform(Matrix4.compose(
      midpoint,
      rotation,
      Vector3(cylinderRadius, distance, cylinderRadius),
    ));
  }
}

/// Visualizes bones as spheres at joints with cylinders connecting them.
///
/// Example usage:
/// ```dart
/// final visualizer = BoneVisualizer(
///   viewer: viewer,
///   asset: asset,
///   skinIndex: 0,
/// );
/// await visualizer.show();
///
/// // After bone transforms change
/// await visualizer.update();
///
/// // When done
/// await visualizer.hide();
/// ```
class BoneVisualizer {
  final ThermionViewer viewer;
  final ThermionAsset asset;
  final int skinIndex;

  // Configuration
  final double sphereRadius;
  final double cylinderRadius;
  final Vector4 jointColor;
  final Vector4 boneColor;

  // Visualization state
  final List<_BoneViz> _bones = [];
  bool _isVisible = false;

  /// Creates a new bone visualizer.
  ///
  /// [viewer] The ThermionViewer to render the visualization
  /// [asset] The asset containing the bones to visualize
  /// [skinIndex] The skin index containing the bones (default: 0)
  /// [sphereRadius] Radius of joint spheres (default: 0.03)
  /// [cylinderRadius] Radius of bone connection cylinders (default: 0.01)
  /// [jointColor] Color of joint spheres as RGBA (default: yellow)
  /// [boneColor] Color of bone cylinders as RGBA (default: light blue)
  BoneVisualizer({
    required this.viewer,
    required this.asset,
    this.skinIndex = 0,
    this.sphereRadius = 0.03,
    this.cylinderRadius = 0.01,
    Vector4? jointColor,
    Vector4? boneColor,
  })  : jointColor = jointColor ?? Vector4(1.0, 1.0, 0.0, 1.0), // Yellow
        boneColor = boneColor ?? Vector4(0.3, 0.8, 1.0, 0.8); // Light blue

  /// Whether the visualization is currently visible.
  bool get isVisible => _isVisible;

  /// Create visualization geometry and add to scene.
  Future<void> show() async {
    if (_isVisible) return;

    final boneNames = await FilamentApp.instance!.animationManager
        .getBoneNames(asset, skinIndex);
    final boneCount = boneNames.length;

    // Create sphere geometry for joints (unit sphere, will scale)
    final sphereGeom = GeometryHelper.sphere(
      normals: true,
      uvs: false,
    );

    // Create cylinder geometry for bones (will be scaled/positioned)
    final cylinderGeom = GeometryHelper.cylinder(
      radius: 1.0, // Will be scaled by cylinderRadius
      length: 1.0, // Will be stretched between bones
      normals: true,
      uvs: false,
    );

    // Get bone parent info
    final am = FilamentApp.instance!.animationManager;

    for (int i = 0; i < boneCount; i++) {
      final parentIndex = am.getBoneParent(asset, skinIndex, i);

      // Get bone entity and position
      final boneEntity = await am.getBone(asset, skinIndex, i);
      if (boneEntity == null) continue;

      final transform = await FilamentApp.instance!.transformManager
          .getWorldTransform(boneEntity);
      final position = transform.getTranslation();

      // Create joint sphere
      final jointMatInst =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      await jointMatInst.setParameterFloat4("baseColorFactor",
          jointColor.r, jointColor.g, jointColor.b, jointColor.a);

      final jointAsset = await viewer.createGeometry(sphereGeom,
          materialInstances: [jointMatInst], addToScene: false);

      // Set sphere scale and position
      await jointAsset.setTransform(Matrix4.compose(
        position,
        Quaternion.identity(),
        Vector3.all(sphereRadius),
      ));
      await viewer.addToScene(jointAsset);

      ThermionAsset? cylinderAsset;

      // Create connection to parent (only create once per edge, from child to parent)
      if (parentIndex >= 0 && parentIndex < i) {
        final parentEntity = await am.getBone(asset, skinIndex, parentIndex);
        if (parentEntity != null) {
          final parentTransform = await FilamentApp.instance!.transformManager
              .getWorldTransform(parentEntity);
          final parentPos = parentTransform.getTranslation();

          final boneMatInst =
              await FilamentApp.instance!.createUnlitMaterialInstance();
          await boneMatInst.setParameterFloat4("baseColorFactor",
              boneColor.r, boneColor.g, boneColor.b, boneColor.a);

          cylinderAsset = await viewer.createGeometry(cylinderGeom,
              materialInstances: [boneMatInst], addToScene: false);

          // Position cylinder between bones
          await _setCylinderTransform(cylinderAsset, parentPos, position);
          await viewer.addToScene(cylinderAsset);
        }
      }

      _bones.add(_BoneViz(
        index: i,
        parentIndex: parentIndex,
        boneEntity: boneEntity,
        jointAsset: jointAsset,
        cylinderAsset: cylinderAsset,
      ));
    }

    _isVisible = true;
  }

  /// Update visualization positions to match current bone transforms.
  ///
  /// Call this after modifying bone transforms to update the visualization.
  Future<void> update() async {
    if (!_isVisible) return;

    final am = FilamentApp.instance!.animationManager;

    for (final bone in _bones) {
      // Update joint position
      final transform = await FilamentApp.instance!.transformManager
          .getWorldTransform(bone.boneEntity);
      final position = transform.getTranslation();
      await bone.jointAsset.setTransform(Matrix4.compose(
        position,
        Quaternion.identity(),
        Vector3.all(sphereRadius),
      ));

      // Update cylinder if exists
      if (bone.cylinderAsset != null &&
          bone.parentIndex >= 0 &&
          bone.parentIndex < bone.index) {
        final parentEntity = await am.getBone(asset, skinIndex, bone.parentIndex);
        if (parentEntity != null) {
          final parentTransform = await FilamentApp.instance!.transformManager
              .getWorldTransform(parentEntity);
          final parentPos = parentTransform.getTranslation();
          await _setCylinderTransform(bone.cylinderAsset!, parentPos, position);
        }
      }
    }
  }

  /// Remove visualization from scene and dispose resources.
  Future<void> hide() async {
    if (!_isVisible) return;

    for (final bone in _bones) {
      await viewer.removeFromScene(bone.jointAsset);
      await viewer.destroyAsset(bone.jointAsset);
      if (bone.cylinderAsset != null) {
        await viewer.removeFromScene(bone.cylinderAsset!);
        await viewer.destroyAsset(bone.cylinderAsset!);
      }
    }
    _bones.clear();
    _isVisible = false;
  }

  Future<void> _setCylinderTransform(
      ThermionAsset cylinder, Vector3 from, Vector3 to) async {
    final direction = (to - from).normalized();
    final distance = from.distanceTo(to);
    final midpoint = (from + to) / 2;

    // Align cylinder (which points up Y) with direction
    final rotation = Quaternion.fromTwoVectors(Vector3(0, 1, 0), direction);

    await cylinder.setTransform(Matrix4.compose(
      midpoint,
      rotation,
      Vector3(cylinderRadius, distance, cylinderRadius),
    ));
  }
}

class _BoneViz {
  final int index;
  final int parentIndex;
  final ThermionEntity boneEntity;
  final ThermionAsset jointAsset;
  final ThermionAsset? cylinderAsset;

  _BoneViz({
    required this.index,
    required this.parentIndex,
    required this.boneEntity,
    required this.jointAsset,
    this.cylinderAsset,
  });
}
