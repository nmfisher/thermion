import 'dart:async';
import 'dart:io';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

/// Visualizes bones with Blender-style head/tail shapes.
///
/// Each bone is rendered as:
/// - A sphere at the bone's head (joint) position
/// - A cylinder extending from head to tail
///
/// Bone length is derived from the distance to the first child bone.
/// Leaf bones use the parent's bone length or a configurable default.
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
  final double envelopeRadius;
  final double defaultBoneLength;
  final Vector4 jointColor;
  final Vector4 boneColor;
  final Vector4 highlightColor;

  // Visualization state
  final List<_BoneViz> _bones = [];
  Map<int, List<int>> _childrenOf = {};
  bool _isVisible = false;
  int? _highlightedBoneIndex;

  // Entity-to-bone mapping for picking
  final Map<ThermionEntity, int> _entityToBoneIndex = {};

  /// Creates a new bone visualizer.
  ///
  /// [viewer] The ThermionViewer to render the visualization
  /// [asset] The asset containing the bones to visualize
  /// [skinIndex] The skin index containing the bones (default: 0)
  /// [sphereRadius] Radius of joint spheres (default: 0.03)
  /// [envelopeRadius] Radius of bone envelope capsules (default: 0.015)
  /// [defaultBoneLength] Fallback length for leaf/orphan bones (default: 0.1)
  /// [jointColor] Color of joint spheres as RGBA (default: yellow)
  /// [boneColor] Color of bone envelopes as RGBA (default: light blue)
  /// [highlightColor] Color for selected/highlighted bones (default: orange)
  BoneVisualizer({
    required this.viewer,
    required this.asset,
    this.skinIndex = 0,
    this.sphereRadius = 0.03,
    this.envelopeRadius = 0.025,
    this.defaultBoneLength = 0.1,
    Vector4? jointColor,
    Vector4? boneColor,
    Vector4? highlightColor,
  }) : jointColor = jointColor ?? Vector4(1.0, 1.0, 0.0, 1.0), // Yellow
       boneColor = boneColor ?? Vector4(0.3, 0.8, 1.0, 1.0), // Light blue
       highlightColor = highlightColor ?? Vector4(1.0, 0.5, 0.0, 1.0); // Orange

  /// Whether the visualization is currently visible.
  bool get isVisible => _isVisible;

  /// Get the bone index for a picked entity.
  ///
  /// Returns the bone index if the entity is a joint sphere or envelope,
  /// or null if the entity is not part of this visualization.
  int? getBoneIndexForEntity(ThermionEntity entity) {
    return _entityToBoneIndex[entity];
  }

  /// Get the parent bone index for a bone.
  ///
  /// Returns -1 if the bone has no parent (root bone) or parent is not in the bone list.
  Future<int> _getBoneParentIndex(int boneIndex, List<ThermionEntity> bones) async {
    if (boneIndex < 0 || boneIndex >= bones.length) return -1;
    final boneEntity = bones[boneIndex];
    final parentEntity = await FilamentApp.instance!.getParent(boneEntity);
    if (parentEntity == null) return -1;
    return bones.indexOf(parentEntity);
  }

  /// Get the bone entity for a given bone index.
  ///
  /// Returns null if the index is out of range or visualization is not visible.
  ThermionEntity? getBoneEntity(int boneIndex) {
    if (boneIndex < 0 || boneIndex >= _bones.length) return null;
    return _bones[boneIndex].boneEntity;
  }

  /// Pick a bone using screen-space distance calculation.
  ///
  /// This method bypasses depth-buffer picking and works even when bones
  /// are visually rendered on top of mesh but geometrically behind it.
  ///
  /// Checks distance to both:
  /// - Joint sphere (bone head position)
  /// - Envelope cylinder (line segment from head to tail)
  ///
  /// [screenX] and [screenY] are screen coordinates (pixels).
  /// [pickThreshold] is the max distance in pixels to consider a bone picked.
  ///
  /// Returns the bone index of the closest bone within threshold, or null.
  Future<int?> pickBoneAtScreen(int screenX, int screenY, {double pickThreshold = 20.0}) async {
    if (!_isVisible || _bones.isEmpty) return null;

    final view = viewer.view;
    final camera = await view.getCamera();
    final viewport = await view.getViewport();
    final projMatrix = await camera.getProjectionMatrix();
    final viewMatrix = await camera.getViewMatrix();
    final tm = FilamentApp.instance!.transformManager;

    final mousePos = Vector2(screenX.toDouble(), screenY.toDouble());

    // Project world position to screen coordinates
    Vector2 projectToScreen(Vector3 worldPos) {
      final clipSpace = projMatrix * viewMatrix * Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
      final ndc = clipSpace / clipSpace.w;
      return Vector2(
        ((ndc.x + 1.0) / 2.0) * viewport.width.toDouble(),
        ((1.0 - ndc.y) / 2.0) * viewport.height.toDouble(),
      );
    }

    // Distance from point to line segment in 2D
    double pointToSegmentDistance(Vector2 p, Vector2 a, Vector2 b) {
      final ab = b - a;
      final lengthSq = ab.dot(ab);
      if (lengthSq < 0.0001) return (p - a).length; // Degenerate segment
      final t = ((p - a).dot(ab) / lengthSq).clamp(0.0, 1.0);
      final closest = a + ab * t;
      return (p - closest).length;
    }

    int? closestBone;
    double minDist = double.infinity;

    for (final bone in _bones) {
      // Get bone head (joint) world position
      final headTransform = await tm.getWorldTransform(bone.boneEntity);
      final headWorldPos = headTransform.getTranslation();
      final headScreenPos = projectToScreen(headWorldPos);

      // Distance to joint sphere
      var dist = (mousePos - headScreenPos).length;

      // Also check distance to envelope cylinder if bone has length
      if (bone.boneLength > 0) {
        // Calculate tail position same way as _calculateTailPosition
        final tailWorldPos = _calculateTailPosition(headTransform, bone.boneLength);
        final tailScreenPos = projectToScreen(tailWorldPos);

        // Distance to cylinder line segment
        final cylinderDist = pointToSegmentDistance(mousePos, headScreenPos, tailScreenPos);
        if (cylinderDist < dist) {
          dist = cylinderDist;
        }
      }

      if (dist < minDist && dist < pickThreshold) {
        minDist = dist;
        closestBone = bone.index;
      }
    }

    return closestBone;
  }

  /// Get the currently highlighted bone index, or null if none.
  int? get highlightedBoneIndex => _highlightedBoneIndex;

  /// Highlight a specific bone by changing its color.
  ///
  /// Pass null to clear the highlight.
  Future<void> highlightBone(int? boneIndex) async {
    if (!_isVisible) return;
    if (boneIndex == _highlightedBoneIndex) return;

    // Unhighlight previous bone
    if (_highlightedBoneIndex != null && _highlightedBoneIndex! < _bones.length) {
      final prevBone = _bones[_highlightedBoneIndex!];
      await prevBone.jointMaterial.setParameterFloat4(
        "baseColorFactor",
        jointColor.r,
        jointColor.g,
        jointColor.b,
        jointColor.a,
      );
      if (prevBone.envelopeMaterial != null) {
        await prevBone.envelopeMaterial!.setParameterFloat4(
          "baseColorFactor",
          boneColor.r,
          boneColor.g,
          boneColor.b,
          boneColor.a,
        );
      }
    }

    _highlightedBoneIndex = boneIndex;

    // Highlight new bone
    if (boneIndex != null && boneIndex >= 0 && boneIndex < _bones.length) {
      final bone = _bones[boneIndex];
      await bone.jointMaterial.setParameterFloat4(
        "baseColorFactor",
        highlightColor.r,
        highlightColor.g,
        highlightColor.b,
        highlightColor.a,
      );
      if (bone.envelopeMaterial != null) {
        await bone.envelopeMaterial!.setParameterFloat4(
          "baseColorFactor",
          highlightColor.r,
          highlightColor.g,
          highlightColor.b,
          highlightColor.a,
        );
      }
    }
  }

  /// Create visualization geometry and add to scene.
  Future<void> show() async {
    if (_isVisible) return;

    final boneEntities = await asset.getBones(skinIndex: skinIndex);
    final boneCount = boneEntities.length;

    if (boneCount == 0) {
      _isVisible = true;
      return;
    }

    final tm = FilamentApp.instance!.transformManager;

    // Build parent-child mapping
    _childrenOf = {};
    for (int i = 0; i < boneCount; i++) {
      final parentIdx = await _getBoneParentIndex(i, boneEntities);
      if (parentIdx >= 0) {
        _childrenOf.putIfAbsent(parentIdx, () => []).add(i);
      }
    }

    // First pass: calculate all bone lengths
    final List<double> boneLengths = List.filled(boneCount, defaultBoneLength);

    for (int i = 0; i < boneCount; i++) {
      final boneEntity = boneEntities[i];
      if (boneEntity == 0) continue;

      final children = _childrenOf[i] ?? [];
      if (children.isNotEmpty) {
        // Use distance to first child as bone length
        final headTransform = await tm.getWorldTransform(boneEntity);
        final headPos = headTransform.getTranslation();

        final childEntity = boneEntities[children.first];
        if (childEntity != 0) {
          final childTransform = await tm.getWorldTransform(childEntity);
          final childPos = childTransform.getTranslation();
          boneLengths[i] = headPos.distanceTo(childPos);
        }
      }
    }

    // Second pass: assign lengths to leaf bones using parent length
    for (int i = 0; i < boneCount; i++) {
      final children = _childrenOf[i] ?? [];
      if (children.isEmpty) {
        // Leaf bone: use parent's length
        final parentIdx = await _getBoneParentIndex(i, boneEntities);
        if (parentIdx >= 0) {
          boneLengths[i] = boneLengths[parentIdx];
        }
        // Otherwise keep defaultBoneLength
      }
    }

    // Create shared geometry
    final sphereGeom = SphereGeometry.sphere(normals: true, uvs: false);
    final cylinderGeom = CylinderGeometry.cylinder(
      radius: 1.0, // Unit cylinder, will be scaled
      length: 1.0,
      normals: true,
      uvs: false,
    );

    // Create bone overlay material for view-dependent flat shading
    final boneMaterial = await FilamentApp.instance!.createBoneOverlayMaterial();

    // Third pass: create visualization for each bone
    for (int i = 0; i < boneCount; i++) {
      final boneEntity = boneEntities[i];
      if (boneEntity == 0) continue;

      final parentIndex = await _getBoneParentIndex(i, boneEntities);
      final boneLength = boneLengths[i];

      // Get bone transform
      final transform = await tm.getWorldTransform(boneEntity);
      final headPos = transform.getTranslation();

      // Create joint sphere
      final jointMatInst = await boneMaterial.createInstance();
      await jointMatInst.setParameterFloat4("baseColorFactor", jointColor.r, jointColor.g, jointColor.b, jointColor.a);

      final jointAsset = await viewer.createGeometry(sphereGeom, materialInstances: [jointMatInst]);

      await jointAsset.setTransform(Matrix4.compose(headPos, Quaternion.identity(), Vector3.all(sphereRadius)));
      await viewer.addToScene(jointAsset);
      await FilamentApp.instance!.setPriority(jointAsset.entity, 7);

      // Create envelope (capsule) for this bone
      ThermionAsset? envelopeAsset;
      MaterialInstance? envelopeMatInst;

      if (boneLength > 0.001) {
        // Skip zero-length bones
        envelopeMatInst = await boneMaterial.createInstance();
        await envelopeMatInst.setParameterFloat4("baseColorFactor", boneColor.r, boneColor.g, boneColor.b, boneColor.a);

        envelopeAsset = await viewer.createGeometry(cylinderGeom, materialInstances: [envelopeMatInst]);

        // Calculate tail position using bone rotation
        final tailPos = _calculateTailPosition(transform, boneLength);
        await _setEnvelopeTransform(envelopeAsset, headPos, tailPos, boneLength);

        await viewer.addToScene(envelopeAsset);
        await FilamentApp.instance!.setPriority(envelopeAsset.entity, 7);
      }

      // Add entity-to-bone mapping for picking
      _entityToBoneIndex[jointAsset.entity] = i;
      if (envelopeAsset != null) {
        _entityToBoneIndex[envelopeAsset.entity] = i;
      }

      _bones.add(
        _BoneViz(
          index: i,
          parentIndex: parentIndex,
          boneEntity: boneEntity,
          jointAsset: jointAsset,
          envelopeAsset: envelopeAsset,
          boneLength: boneLength,
          jointMaterial: jointMatInst,
          envelopeMaterial: envelopeMatInst,
        ),
      );
    }

    _isVisible = true;
  }

  /// Calculate tail position from bone transform and length.
  ///
  /// The bone direction is the local Y-axis rotated to world space.
  Vector3 _calculateTailPosition(Matrix4 worldTransform, double length) {
    final headPos = worldTransform.getTranslation();

    // Extract rotation from the transform
    final rotation = Quaternion.fromRotation(worldTransform.getRotation());

    // Bone direction is local Y-axis in world space
    final direction = rotation.rotate(Vector3(0, 1, 0));

    return headPos + direction * length;
  }

  /// Set envelope (cylinder) transform to span from head to tail.
  ///
  /// The cylinder's bottom end should be at the head position and top at tail.
  /// The unit cylinder has length=1 (from -0.5 to +0.5 on Y) with radius=1.
  Future<void> _setEnvelopeTransform(ThermionAsset envelope, Vector3 head, Vector3 tail, double length) async {
    final direction = (tail - head).normalized();

    // Rotate cylinder (which points along Y) to align with bone direction
    final rotation = Quaternion.fromTwoVectors(Vector3(0, 1, 0), direction);

    // The unit cylinder is centered at origin with length=1 (-0.5 to +0.5).
    // After scaling Y by length, the cylinder spans from -length/2 to +length/2.
    // We want the bottom at head and top at tail.
    // So position = head + direction * (length/2) = midpoint
    final midpoint = head + direction * (length / 2);

    // Scale: X and Z are envelope radius, Y is bone length
    // (since unit cylinder length is 1, scaling by length gives total length)
    await envelope.setTransform(Matrix4.compose(midpoint, rotation, Vector3(envelopeRadius, length, envelopeRadius)));
  }

  /// Same as [_setEnvelopeTransform] but uses render-thread-safe async method.
  Future<void> _setEnvelopeTransformAsync(ThermionAsset envelope, Vector3 head, Vector3 tail, double length) async {
    final direction = (tail - head).normalized();
    final rotation = Quaternion.fromTwoVectors(Vector3(0, 1, 0), direction);
    final midpoint = head + direction * (length / 2);

    await FilamentApp.instance!.transformManager.setTransformAsync(
      envelope.entity,
      Matrix4.compose(midpoint, rotation, Vector3(envelopeRadius, length, envelopeRadius)),
    );
  }

  /// Update visualization positions to match current bone transforms.
  ///
  /// Call this after modifying bone transforms to update the visualization.
  /// Uses render-thread-safe async transform updates to avoid race conditions.
  Future<void> update() async {
    if (!_isVisible) return;

    final tm = FilamentApp.instance!.transformManager;

    for (final bone in _bones) {
      // Get current bone transform
      final transform = tm.getWorldTransform(bone.boneEntity);
      final headPos = transform.getTranslation();

      // Update joint sphere position using async (thread-safe) method
      await tm.setTransformAsync(
        bone.jointAsset.entity,
        Matrix4.compose(headPos, Quaternion.identity(), Vector3.all(sphereRadius)),
      );

      // Update envelope if exists
      if (bone.envelopeAsset != null && bone.boneLength > 0.001) {
        final tailPos = _calculateTailPosition(transform, bone.boneLength);
        await _setEnvelopeTransformAsync(bone.envelopeAsset!, headPos, tailPos, bone.boneLength);
      }
    }
  }

  /// Remove visualization from scene and dispose resources.
  Future<void> hide() async {
    if (!_isVisible) return;

    for (final bone in _bones) {
      await viewer.removeFromScene(bone.jointAsset);
      await viewer.destroyAsset(bone.jointAsset);
      if (bone.envelopeAsset != null) {
        await viewer.removeFromScene(bone.envelopeAsset!);
        await viewer.destroyAsset(bone.envelopeAsset!);
      }
    }
    _bones.clear();
    _childrenOf.clear();
    _entityToBoneIndex.clear();
    _isVisible = false;
  }
}

class _BoneViz {
  final int index;
  final int parentIndex;
  final ThermionEntity boneEntity;
  final ThermionAsset jointAsset;
  final ThermionAsset? envelopeAsset;
  final double boneLength;
  final MaterialInstance jointMaterial;
  final MaterialInstance? envelopeMaterial;

  _BoneViz({
    required this.index,
    required this.parentIndex,
    required this.boneEntity,
    required this.jointAsset,
    this.envelopeAsset,
    required this.boneLength,
    required this.jointMaterial,
    this.envelopeMaterial,
  });
}

void main() async {
  final testHelper = TestHelper("bone_picking");
  await testHelper.setup();

  test('pick bone with screen-space picking', () async {
    await testHelper.withViewer((viewer) async {
      // 1. Load armature asset
      final assetData = File('${testHelper.testDir}/assets/cube_with_morph_targets.glb').readAsBytesSync();
      final asset = await viewer.loadGltfFromBuffer(assetData);
      await viewer.addToScene(asset);

      // Add lighting so we can see the cube
      await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      // 2. Create bone visualizer
      final boneVisualizer = BoneVisualizer(viewer: viewer, asset: asset, skinIndex: 0, sphereRadius: 0.1);
      await boneVisualizer.show();

      // Capture initial frame to see scene
      await testHelper.capture(viewer.view, "bone_scene_initial");

      print('Asset entity: ${asset.entity}');
      print('Bone visualizer visible: ${boneVisualizer.isVisible}');

      // 3. Get bone world positions for logging
      final boneEntities = await asset.getBones(skinIndex: 0);
      final tm = FilamentApp.instance!.transformManager;

      print('Found ${boneEntities.length} bones');

      // 4. Test screen-space picking for ALL bones (including bone 0 inside mesh!)
      for (int boneIndex = 0; boneIndex < boneEntities.length; boneIndex++) {
        final boneEntity = boneEntities[boneIndex];
        if (boneEntity == 0) {
          print('Bone $boneIndex: entity is 0, skipping');
          continue;
        }

        // Get world position and project to screen
        final transform = await tm.getWorldTransform(boneEntity);
        final worldPos = transform.getTranslation();

        final camera = await viewer.getActiveCamera();
        final viewport = await viewer.view.getViewport();
        final projMatrix = await camera.getProjectionMatrix();
        final viewMatrix = await camera.getViewMatrix();

        final clipPos = (projMatrix * viewMatrix) * Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
        final ndcPos = clipPos.xyz / clipPos.w;

        final screenX = ((ndcPos.x + 1) / 2 * viewport.width).toInt();
        final screenY = ((1 - ndcPos.y) / 2 * viewport.height).toInt();

        print('Bone $boneIndex: worldPos=$worldPos -> screen=($screenX, $screenY)');

        // 5. Use screen-space picking (bypasses depth buffer!)
        final pickedBoneIndex = await boneVisualizer.pickBoneAtScreen(screenX, screenY);

        print('  -> screen-space pick: boneIndex=$pickedBoneIndex');

        // Render a frame to capture
        await testHelper.capture(viewer.view, "bone_pick_$boneIndex");

        // 6. Verify screen-space picking works for ALL bones
        expect(pickedBoneIndex, boneIndex, reason: 'Screen-space picking at bone $boneIndex should return that bone');

        // Highlight and capture
        await boneVisualizer.highlightBone(pickedBoneIndex);
        await testHelper.capture(viewer.view, "bone_highlighted_$boneIndex");
      }

      await boneVisualizer.hide();
    }, cameraPosition: Vector3(3, 3, 5));
  });

  test('pick bone with empty space behind', () async {
    await testHelper.withViewer((viewer) async {
      // Load asset
      final assetData = File('${testHelper.testDir}/assets/cube_with_morph_targets.glb').readAsBytesSync();
      final asset = await viewer.loadGltfFromBuffer(assetData);
      await viewer.addToScene(asset);

      // Add lighting
      await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

      // Create bone visualizer
      final boneVisualizer = BoneVisualizer(
        viewer: viewer,
        asset: asset,
        skinIndex: 0,
        sphereRadius: 0.1, // Larger for easier picking
      );
      await boneVisualizer.show();

      // Hide mesh to isolate bone sphere picking
      await viewer.removeFromScene(asset);

      // Position camera to look at bone 1 from above - so empty space is behind it
      final camera = await viewer.getActiveCamera();
      await camera.lookAt(
        Vector3(0, 5, 0.1), // Camera above looking down
        focus: Vector3(0, 1, 0), // Focus on bone 1 position
        up: Vector3(0, 0, -1),
      );

      await testHelper.capture(viewer.view, "bone_empty_behind");

      // Pick at center of screen (should hit bone 1 with empty space behind)
      final viewport = await viewer.view.getViewport();
      final centerX = viewport.width ~/ 2;
      final centerY = viewport.height ~/ 2;

      // The bone overlay material is blended (transparent), and View::pick
      // only considers opaque renderables unless transparent picking is
      // enabled (it is disabled by default in Filament).
      await viewer.view.setTransparentPickingEnabled(true);

      print('Picking at center: ($centerX, $centerY)');

      final completer = Completer<PickResult>();
      await viewer.view.pick(centerX, centerY, completer.complete);

      for (int i = 0; i < 10; i++) {
        await testHelper.capture(viewer.view, "bone_empty_pick_$i");
        if (completer.isCompleted) break;
      }

      expect(completer.isCompleted, true);
      final result = await completer.future;
      final pickedBoneIndex = boneVisualizer.getBoneIndexForEntity(result.entity);

      print(
        'Picked entity=${result.entity}, depth=${result.depth}, '
        'mappedBone=$pickedBoneIndex',
      );

      // Should pick bone 1, not return null (which would indicate empty space)
      expect(pickedBoneIndex, isNotNull, reason: 'Should pick bone sphere, not empty space');

      // Highlight the picked bone and capture
      if (pickedBoneIndex != null) {
        await boneVisualizer.highlightBone(pickedBoneIndex);
        await testHelper.capture(viewer.view, "bone_empty_highlighted");
      }

      await boneVisualizer.hide();
    }, cameraPosition: Vector3(0, 5, 0.1));
  });
}
