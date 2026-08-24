import 'dart:math' as math;
import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';

enum TransformationGizmoType { translation, scale, rotation }

enum GizmoAxis { x, y, z, none }

/// Camera/viewport state for a single input event.
///
/// [TransformationGizmo.update], [pickAxis] and the drag handlers all need
/// the same camera matrices; fetching them once per event and passing this
/// object down avoids re-reading (and re-allocating) them 2-3 times per
/// pointer event.
class GizmoCameraContext {
  final Viewport viewport;
  final Matrix4 projectionMatrix;
  final Matrix4 viewMatrix;
  final Matrix4 modelMatrix;
  final Vector3 cameraPosition;

  GizmoCameraContext({
    required this.viewport,
    required this.projectionMatrix,
    required this.viewMatrix,
    required this.modelMatrix,
    required this.cameraPosition,
  });

  static Future<GizmoCameraContext> fetch(ThermionViewer viewer) async {
    final camera = await viewer.getActiveCamera();
    final view = await viewer.view;
    return GizmoCameraContext(
      viewport: await view.getViewport(),
      projectionMatrix: await camera.getProjectionMatrix(),
      viewMatrix: await camera.getViewMatrix(),
      modelMatrix: await camera.getModelMatrix(),
      cameraPosition: await camera.getPosition(),
    );
  }

  /// Projects a world-space point to screen (viewport) space.
  Vector2 projectToScreen(Vector3 worldPos) {
    final clipSpace = projectionMatrix * viewMatrix * Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
    final ndc = clipSpace / clipSpace.w;
    return Vector2(
      ((ndc.x + 1.0) / 2.0) * viewport.width.toDouble(),
      ((1.0 - ndc.y) / 2.0) * viewport.height.toDouble(),
    );
  }
}

class TransformationGizmo {
  final ThermionViewer viewer;

  ThermionEntity? _rootEntity;

  // Assets for cleanup
  final List<ThermionAsset> _assets = [];

  // Rotation drag markers
  ThermionEntity? _startMarker;
  ThermionEntity? _currentMarker;
  ThermionAsset? _startMarkerAsset;
  ThermionAsset? _currentMarkerAsset;

  MaterialInstance? _redMat;
  MaterialInstance? _greenMat;
  MaterialInstance? _blueMat;
  MaterialInstance? _whiteMat;
  MaterialInstance? _yellowMat;

  ThermionEntity? _attachedTarget;

  final double _axisLength = 1.5;
  final double _handleSize = 0.25;
  final double _shaftRadius = 0.03;
  final double _markerRadius = 0.15;
  final double _ringRadius = 1.0;

  // Gizmo type
  TransformationGizmoType _type = TransformationGizmoType.translation;

  // Drag state
  GizmoAxis _activeAxis = GizmoAxis.none;
  Vector2? _dragStartScreen;
  Matrix4? _targetStartTransform;
  Matrix4? _lastComputedWorldTransform; // Last computed world transform for callback

  // Last transform applied to the root entity (used to skip redundant writes)
  Matrix4? _lastRootTransform;

  // Hover state
  GizmoAxis _hoveredAxis = GizmoAxis.none;

  // Disposal state
  bool _isDisposed = false;

  // Visibility state
  bool _isVisible = true;

  TransformationGizmo(this.viewer);

  Future<void> create({TransformationGizmoType type = TransformationGizmoType.translation}) async {
    if (_isDisposed) return;
    _type = type;

    // 1. Create Unlit Materials (No depth write for "always on top" effect)
    _redMat = await _createGizmoMaterial(1.0, 0.0, 0.0);
    if (_redMat == null) return;
    _greenMat = await _createGizmoMaterial(0.0, 1.0, 0.0);
    if (_greenMat == null) return;
    _blueMat = await _createGizmoMaterial(0.0, 0.0, 1.0);
    if (_blueMat == null) return;
    _whiteMat = await _createGizmoMaterial(1.0, 1.0, 1.0, alpha: 1.0);
    if (_whiteMat == null) return;
    _yellowMat = await _createGizmoMaterial(1.0, 1.0, 0.0, alpha: 1.0);
    if (_yellowMat == null) return;

    // 2. Create Root entity (no geometry needed - just a transform parent)
    final rootEntity = await viewer.app.createEntity();
    if (_isDisposed) {
      await viewer.app.destroyEntity(rootEntity);
      return;
    }
    _rootEntity = rootEntity;

    if (type == TransformationGizmoType.translation) {
      await _buildTranslationAxes();
    } else if (type == TransformationGizmoType.rotation) {
      await _buildRotationRings();
    }
  }

  Future<void> _buildTranslationAxes() async {
    if (_isDisposed) return;
    // Generate manual geometry (No Normals, No UVs -> Safe for Unlit)
    final shaftGeom = _createCylinderGeometry(_shaftRadius, _axisLength, 12);
    final headGeom = _createConeGeometry(_handleSize, _handleSize * 2.0, 12);

    // Y Axis (Green, Up)
    await _createAxis(shaftGeom, headGeom, _greenMat!, Vector3(0, 1, 0));
    if (_isDisposed) return;

    // X Axis (Red, Right)
    await _createAxis(shaftGeom, headGeom, _redMat!, Vector3(1, 0, 0));
    if (_isDisposed) return;

    // Z Axis (Blue, Forward)
    await _createAxis(shaftGeom, headGeom, _blueMat!, Vector3(0, 0, 1));
    if (_isDisposed) return;
  }

  Future<void> _buildRotationRings() async {
    if (_isDisposed) return;
    final tubeRadius = 0.03;
    final ringSegments = 64;
    final tubeSegments = 12;

    final ringGeom = _createTorusGeometry(_ringRadius, tubeRadius, ringSegments, tubeSegments);

    // Y Axis Ring (Green, in XY plane - represents rotation around Y)
    await _createRing(ringGeom, _greenMat!, Vector3(0, 1, 0));
    if (_isDisposed) return;

    // X Axis Ring (Red, in YZ plane - represents rotation around X)
    await _createRing(ringGeom, _redMat!, Vector3(1, 0, 0));
    if (_isDisposed) return;

    // Z Axis Ring (Blue, in XY plane - represents rotation around Z)
    await _createRing(ringGeom, _blueMat!, Vector3(0, 0, 1));
    if (_isDisposed) return;

    // Create markers for showing drag start/current positions
    await _createMarkers();
  }

  Future<ThermionEntity> _createRing(Geometry ring, MaterialInstance mat, Vector3 axis) async {
    final ringAsset = await viewer.app.createGeometry(ring, materialInstances: [mat]);

    if (!await _takeAssetOwnership(ringAsset)) {
      return ringAsset.entity; // Return but won't be used
    }

    // Parent to root entity so it moves with the gizmo
    if (_rootEntity != null) {
      viewer.app.transformManager.setParent(ringAsset.entity, _rootEntity!);
    }

    // Calculate rotation to align ring with the axis
    Quaternion rotation;
    if (axis.y > 0) {
      rotation = Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2);
    } else if (axis.x > 0) {
      rotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2);
    } else {
      rotation = Quaternion.identity();
    }

    final ringMatrix = Matrix4.compose(Vector3.zero(), rotation, Vector3.all(1.0));
    await viewer.app.setTransform(ringAsset.entity, ringMatrix);
    if (_isDisposed) return ringAsset.entity;
    await viewer.app.setPriority(ringAsset.entity, 7);
    return ringAsset.entity;
  }

  // Returns Pair<Shaft, Head>
  Future<(ThermionEntity, ThermionEntity)> _createAxis(
    Geometry shaft,
    Geometry head,
    MaterialInstance mat,
    Vector3 direction,
  ) async {
    // Create Shaft
    final shaftAsset = await viewer.app.createGeometry(shaft, materialInstances: [mat]);

    if (!await _takeAssetOwnership(shaftAsset)) {
      // return dummy, loop will catch disposed flag
      return (shaftAsset.entity, shaftAsset.entity);
    }

    // Create Head
    final headAsset = await viewer.app.createGeometry(head, materialInstances: [mat]);

    if (!await _takeAssetOwnership(headAsset)) {
      return (shaftAsset.entity, headAsset.entity);
    }

    // Parent to root entity so they move with the gizmo
    if (_rootEntity != null) {
      viewer.app.transformManager.setParent(shaftAsset.entity, _rootEntity!);
      viewer.app.transformManager.setParent(headAsset.entity, _rootEntity!);
    }

    // Calculations
    final rotation = Quaternion.fromTwoVectors(Vector3(0, 1, 0), direction);
    final shaftPos = direction * (_axisLength / 2); // Center shaft
    final headPos = direction * _axisLength; // Place head at tip

    final shaftMatrix = Matrix4.compose(shaftPos, rotation, Vector3.all(1.0));
    final headMatrix = Matrix4.compose(headPos, rotation, Vector3.all(1.0));

    // Set local transforms
    await viewer.app.setTransform(shaftAsset.entity, shaftMatrix);
    if (_isDisposed) return (shaftAsset.entity, headAsset.entity);
    await viewer.app.setTransform(headAsset.entity, headMatrix);

    return (shaftAsset.entity, headAsset.entity);
  }

  // --- Manual Geometry Generators ---

  Geometry _createCylinderGeometry(double radius, double length, int segments) {
    final vertices = <double>[];
    final indices = <int>[];
    final halfLen = length / 2;

    // Top Ring
    for (int i = 0; i < segments; i++) {
      final theta = (i / segments) * 2 * math.pi;
      vertices.addAll([radius * math.cos(theta), halfLen, radius * math.sin(theta)]);
    }
    // Bottom Ring
    for (int i = 0; i < segments; i++) {
      final theta = (i / segments) * 2 * math.pi;
      vertices.addAll([radius * math.cos(theta), -halfLen, radius * math.sin(theta)]);
    }

    // Indices (Side walls)
    for (int i = 0; i < segments; i++) {
      final top1 = i;
      final top2 = (i + 1) % segments;
      final bot1 = i + segments;
      final bot2 = (i + 1) % segments + segments;

      indices.addAll([top1, bot1, top2]);
      indices.addAll([top2, bot1, bot2]);
    }

    return Geometry(
      Float32List.fromList(vertices),
      Uint16List.fromList(indices),
      primitiveType: PrimitiveType.TRIANGLES,
    );
  }

  Geometry _createConeGeometry(double radius, double height, int segments) {
    final vertices = <double>[];
    final indices = <int>[];

    // 0: Tip
    vertices.addAll([0, height, 0]);

    // 1..N: Base Ring
    for (int i = 0; i < segments; i++) {
      final theta = (i / segments) * 2 * math.pi;
      vertices.addAll([radius * math.cos(theta), 0, radius * math.sin(theta)]);
    }

    // N+1: Base Center (Cap)
    vertices.addAll([0, 0, 0]);

    // Indices - Sides
    for (int i = 0; i < segments; i++) {
      final current = i + 1;
      final next = (i + 1) % segments + 1;
      indices.addAll([0, next, current]);
    }

    // Indices - Bottom Cap
    final centerIdx = segments + 1;
    for (int i = 0; i < segments; i++) {
      final current = i + 1;
      final next = (i + 1) % segments + 1;
      indices.addAll([centerIdx, current, next]);
    }

    return Geometry(
      Float32List.fromList(vertices),
      Uint16List.fromList(indices),
      primitiveType: PrimitiveType.TRIANGLES,
    );
  }

  Geometry _createTorusGeometry(double ringRadius, double tubeRadius, int ringSegments, int tubeSegments) {
    final vertices = <double>[];
    final indices = <int>[];

    for (int i = 0; i < ringSegments; i++) {
      final u = (i / ringSegments) * 2 * math.pi;
      final cosU = math.cos(u);
      final sinU = math.sin(u);

      for (int j = 0; j < tubeSegments; j++) {
        final v = (j / tubeSegments) * 2 * math.pi;
        final cosV = math.cos(v);
        final sinV = math.sin(v);

        final x = (ringRadius + tubeRadius * cosV) * cosU;
        final y = (ringRadius + tubeRadius * cosV) * sinU;
        final z = tubeRadius * sinV;

        vertices.addAll([x, y, z]);
      }
    }

    for (int i = 0; i < ringSegments; i++) {
      for (int j = 0; j < tubeSegments; j++) {
        final nextI = (i + 1) % ringSegments;
        final nextJ = (j + 1) % tubeSegments;

        final current = i * tubeSegments + j;
        final nextTube = i * tubeSegments + nextJ;
        final nextRing = nextI * tubeSegments + j;
        final nextBoth = nextI * tubeSegments + nextJ;

        indices.addAll([current, nextRing, nextTube]);
        indices.addAll([nextTube, nextRing, nextBoth]);
      }
    }

    return Geometry(
      Float32List.fromList(vertices),
      Uint16List.fromList(indices),
      primitiveType: PrimitiveType.TRIANGLES,
    );
  }

  Geometry _createSphereGeometry(double radius, int segments, int rings) {
    final vertices = <double>[];
    final indices = <int>[];

    // Generate vertices
    for (int ring = 0; ring <= rings; ring++) {
      final phi = (ring / rings) * math.pi;
      final sinPhi = math.sin(phi);
      final cosPhi = math.cos(phi);

      for (int seg = 0; seg <= segments; seg++) {
        final theta = (seg / segments) * 2 * math.pi;
        final sinTheta = math.sin(theta);
        final cosTheta = math.cos(theta);

        final x = radius * sinPhi * cosTheta;
        final y = radius * cosPhi;
        final z = radius * sinPhi * sinTheta;

        vertices.addAll([x, y, z]);
      }
    }

    // Generate indices
    for (int ring = 0; ring < rings; ring++) {
      for (int seg = 0; seg < segments; seg++) {
        final current = ring * (segments + 1) + seg;
        final next = current + segments + 1;

        indices.addAll([current, next, current + 1]);
        indices.addAll([current + 1, next, next + 1]);
      }
    }

    return Geometry(
      Float32List.fromList(vertices),
      Uint16List.fromList(indices),
      primitiveType: PrimitiveType.TRIANGLES,
    );
  }

  Future<MaterialInstance?> _createGizmoMaterial(double r, double g, double b, {double alpha = 0.5}) async {
    if (_isDisposed) return null;
    final material = await viewer.app.createGizmoMaterial();
    if (_isDisposed) return null;

    final mat = await material.createInstance();
    if (_isDisposed) {
      await mat.destroy();
      return null;
    }

    await mat.setParameterFloat4("baseColorFactor", r, g, b, alpha);
    if (_isDisposed) {
      await mat.destroy();
      return null;
    }
    return mat;
  }

  /// Registers [asset] before awaiting scene insertion so disposal owns every
  /// resource throughout the entire asynchronous creation sequence.
  Future<bool> _takeAssetOwnership(ThermionAsset asset) async {
    if (_isDisposed) {
      await viewer.destroyAsset(asset);
      return false;
    }

    _assets.add(asset);
    await viewer.addToScene(asset);
    return !_isDisposed;
  }

  Future<void> attachTo(ThermionEntity entity) async {
    if (_isDisposed) return;
    _attachedTarget = entity;

    // Re-add to scene if previously hidden
    if (!_isVisible) {
      await _show();
    }
    await update();
  }

  /// Detach the gizmo from the current target and hide it.
  Future<void> detach() async {
    if (_isDisposed) return;
    _attachedTarget = null;
    await _hide();
  }

  Future<void> _hide() async {
    if (!_isVisible || _isDisposed) return;
    _isVisible = false;
    for (final asset in _assets) {
      await viewer.removeFromScene(asset);
    }
  }

  Future<void> _show() async {
    if (_isVisible || _isDisposed) return;
    _isVisible = true;
    for (final asset in _assets) {
      await viewer.addToScene(asset);
    }
  }

  Future<void> update({Vector3? cameraPosition, Vector3? position}) async {
    if (_isDisposed || _attachedTarget == null || _rootEntity == null) return;

    // Don't reposition gizmo during active drag - we want it to stay at the
    // original position for the duration of the drag operation
    if (isActive && position == null) return;

    final targetPos =
        position ?? (await viewer.app.transformManager.getWorldTransform(_attachedTarget!)).getTranslation();

    if (_isDisposed) return;

    // Always get camera position for scale calculation
    final camPos = cameraPosition ?? await (await viewer.getActiveCamera()).getPosition();
    if (_isDisposed) return;

    final dist = targetPos.distanceTo(camPos);

    // Scale proportionally to distance to maintain constant screen-space size
    // Smaller values = smaller gizmo on screen
    const screenSizeFactor = 0.15;
    final scale = dist * screenSizeFactor / _axisLength;

    final rootTransform = Matrix4.compose(targetPos, Quaternion.identity(), Vector3.all(scale));

    // Input events fire far more often than the camera or target moves;
    // skip the FFI write when the computed transform is unchanged.
    if (_lastRootTransform != null && _transformsEqual(_lastRootTransform!, rootTransform)) {
      return;
    }
    await viewer.app.setTransform(_rootEntity!, rootTransform);
    _lastRootTransform = rootTransform;
  }

  static bool _transformsEqual(Matrix4 a, Matrix4 b) {
    for (int i = 0; i < 16; i++) {
      if (a.storage[i] != b.storage[i]) return false;
    }
    return true;
  }

  Future<GizmoAxis> pickAxis(int x, int y, {GizmoCameraContext? context}) async {
    if (_isDisposed || _attachedTarget == null) return GizmoAxis.none;

    // Use screen-space picking to avoid depth buffer issues
    final ctx = context ?? await GizmoCameraContext.fetch(viewer);
    if (_isDisposed) return GizmoAxis.none;

    // Get gizmo world position
    final gizmoTransform = await viewer.app.transformManager.getWorldTransform(_rootEntity!);
    final gizmoWorldPos = gizmoTransform.getTranslation();
    final gizmoScale = gizmoTransform.getColumn(0).xyz.length;

    // Project a point from world space to screen space
    Vector2 projectToScreen(Vector3 worldPos) => ctx.projectToScreen(worldPos);

    // Distance from point to line segment in 2D
    double pointToSegmentDistance(Vector2 p, Vector2 a, Vector2 b) {
      final ab = b - a;
      final ap = p - a;
      final t = (ap.dot(ab) / ab.dot(ab)).clamp(0.0, 1.0);
      final closest = a + ab * t;
      return (p - closest).length;
    }

    final mousePos = Vector2(x.toDouble(), y.toDouble());
    final gizmoScreenPos = projectToScreen(gizmoWorldPos);

    // Threshold in pixels for picking
    const pickThreshold = 15.0;

    // Test each axis
    double minDist = double.infinity;
    GizmoAxis closestAxis = GizmoAxis.none;

    for (final axis in [GizmoAxis.x, GizmoAxis.y, GizmoAxis.z]) {
      final axisDir = _getAxisVector(axis);
      // Total length includes shaft + cone head
      final totalAxisLength = _axisLength + _handleSize * 2.0;
      final axisEnd = gizmoWorldPos + axisDir * totalAxisLength * gizmoScale;
      final axisScreenEnd = projectToScreen(axisEnd);

      double dist;
      if (_type == TransformationGizmoType.rotation) {
        // For rotation rings, check distance to the ring circle in screen space
        // Approximate by checking distance to multiple points on the ring
        dist = double.infinity;
        const segments = 32;
        for (int i = 0; i < segments; i++) {
          final angle1 = (i / segments) * 2 * math.pi;
          final angle2 = ((i + 1) / segments) * 2 * math.pi;

          // Get points on the ring in world space
          Vector3 ringPoint1, ringPoint2;
          final ringRadius = 1.0 * gizmoScale;
          if (axis == GizmoAxis.x) {
            ringPoint1 = gizmoWorldPos + Vector3(0, math.cos(angle1), math.sin(angle1)) * ringRadius;
            ringPoint2 = gizmoWorldPos + Vector3(0, math.cos(angle2), math.sin(angle2)) * ringRadius;
          } else if (axis == GizmoAxis.y) {
            ringPoint1 = gizmoWorldPos + Vector3(math.cos(angle1), 0, math.sin(angle1)) * ringRadius;
            ringPoint2 = gizmoWorldPos + Vector3(math.cos(angle2), 0, math.sin(angle2)) * ringRadius;
          } else {
            ringPoint1 = gizmoWorldPos + Vector3(math.cos(angle1), math.sin(angle1), 0) * ringRadius;
            ringPoint2 = gizmoWorldPos + Vector3(math.cos(angle2), math.sin(angle2), 0) * ringRadius;
          }

          final screenPoint1 = projectToScreen(ringPoint1);
          final screenPoint2 = projectToScreen(ringPoint2);
          final segDist = pointToSegmentDistance(mousePos, screenPoint1, screenPoint2);
          if (segDist < dist) dist = segDist;
        }
      } else {
        // For translation axes, check distance to the axis line
        dist = pointToSegmentDistance(mousePos, gizmoScreenPos, axisScreenEnd);
      }

      if (dist < minDist && dist < pickThreshold) {
        minDist = dist;
        closestAxis = axis;
      }
    }

    return closestAxis;
  }

  // --- Drag Interaction ---

  bool get isActive => _activeAxis != GizmoAxis.none;

  /// Get the last computed world transform during drag.
  /// This is the exact transform the gizmo computed, avoiding any
  /// floating point drift from reading back via getWorldTransform.
  Matrix4? get lastComputedWorldTransform => _lastComputedWorldTransform;

  Future<bool> startDrag(int screenX, int screenY, {GizmoCameraContext? context}) async {
    if (_isDisposed || _attachedTarget == null) return false;

    // Pick to find which axis was clicked
    _activeAxis = await pickAxis(screenX, screenY, context: context);
    if (_isDisposed || _activeAxis == GizmoAxis.none) return false;

    // Store initial state
    _dragStartScreen = Vector2(screenX.toDouble(), screenY.toDouble());
    _targetStartTransform = await viewer.app.transformManager.getWorldTransform(_attachedTarget!);
    _lastComputedWorldTransform = null;

    if (_isDisposed) return false;

    // For rotation gizmos, position markers at click location on ring
    if (_type == TransformationGizmoType.rotation) {
      final startPos = await _getMarkerPositionOnRing(screenX, screenY, _activeAxis, context: context);
      if (_isDisposed) return false;

      if (startPos != null) {
        if (_startMarker != null) {
          await _updateMarkerPosition(_startMarker!, startPos);
        }
        if (_currentMarker != null) {
          await _updateMarkerPosition(_currentMarker!, startPos);
        }
      }
    }

    // Update highlights for active state
    await _updateHighlights();

    return true;
  }

  Future<void> hover(int screenX, int screenY, {GizmoCameraContext? context}) async {
    if (_isDisposed || _activeAxis != GizmoAxis.none) return;

    final hovered = await pickAxis(screenX, screenY, context: context);
    if (_isDisposed) return;

    if (hovered != _hoveredAxis) {
      _hoveredAxis = hovered;
      await _updateHighlights();
    }
  }

  Future<void> updateDrag(int screenX, int screenY, {GizmoCameraContext? context}) async {
    if (_isDisposed || _activeAxis == GizmoAxis.none || _attachedTarget == null) return;

    final ctx = context ?? await GizmoCameraContext.fetch(viewer);
    if (_isDisposed) return;

    if (_type == TransformationGizmoType.rotation) {
      await _updateRotationDrag(screenX, screenY, ctx);
    } else {
      await _updateTranslationDrag(screenX, screenY, ctx);
    }
  }

  Future<void> _updateTranslationDrag(int screenX, int screenY, GizmoCameraContext ctx) async {
    if (_isDisposed) return;
    final currentScreen = Vector2(screenX.toDouble(), screenY.toDouble());
    final screenDelta = currentScreen - _dragStartScreen!;

    final viewport = ctx.viewport;
    final projectionMatrix = ctx.projectionMatrix;
    final viewMatrix = ctx.viewMatrix;
    final inverseViewMatrix = ctx.modelMatrix;
    final inverseProjectionMatrix = projectionMatrix.clone()..invert();

    // Re-check validity before using transforms
    if (_isDisposed || _targetStartTransform == null) return;

    // Get gizmo position in screen space
    final gizmoWorldPos = _targetStartTransform!.getTranslation();
    final gizmoClipSpace =
        projectionMatrix * viewMatrix * Vector4(gizmoWorldPos.x, gizmoWorldPos.y, gizmoWorldPos.z, 1.0);

    var gizmoNdc = gizmoClipSpace / gizmoClipSpace.w;
    var gizmoScreenSpace = Vector2(
      ((gizmoNdc.x / 2) + 0.5) * viewport.width.toDouble(),
      viewport.height.toDouble() - (((gizmoNdc.y / 2) + 0.5) * viewport.height.toDouble()),
    );

    // Apply screen delta
    gizmoScreenSpace += screenDelta;

    // Convert back to world space
    gizmoNdc = Vector4(
      ((gizmoScreenSpace.x / viewport.width.toDouble()) - 0.5) * 2,
      (((gizmoScreenSpace.y / viewport.height.toDouble())) - 0.5) * -2,
      gizmoNdc.z,
      1.0,
    );

    var gizmoViewSpace = inverseProjectionMatrix * gizmoNdc;
    gizmoViewSpace /= gizmoViewSpace.w;

    final projectedWorldPos = (inverseViewMatrix * gizmoViewSpace).xyz;
    final worldDelta = projectedWorldPos - gizmoWorldPos;

    // Constrain to active axis
    final axisVector = _getAxisVector(_activeAxis);
    final constrainedDelta = axisVector * worldDelta.dot(axisVector);

    // Update target transform in world space
    final newWorldPos = gizmoWorldPos + constrainedDelta;
    final newWorldTransform = _targetStartTransform!.clone();
    newWorldTransform.setTranslation(newWorldPos);

    // Store the computed world transform for the callback to use
    _lastComputedWorldTransform = newWorldTransform;

    if (_attachedTarget != null && !_isDisposed) {
      // Convert world transform to local transform for proper hierarchy
      // handling
      final localTransform = _worldToLocalTransform(_attachedTarget!, newWorldTransform);
      await viewer.app.setTransform(_attachedTarget!, localTransform);

      // Update gizmo position directly only if still alive
      if (!_isDisposed) {
        await update(cameraPosition: ctx.cameraPosition, position: newWorldPos);
      }
    }
  }

  Future<void> _updateRotationDrag(int screenX, int screenY, GizmoCameraContext ctx) async {
    if (_isDisposed) return;
    final currentScreen = Vector2(screenX.toDouble(), screenY.toDouble());

    final viewport = ctx.viewport;
    final projectionMatrix = ctx.projectionMatrix;
    final viewMatrix = ctx.viewMatrix;
    final cameraPosition = ctx.cameraPosition;

    if (_isDisposed || _targetStartTransform == null) return;

    final gizmoWorldPos = _targetStartTransform!.getTranslation();
    final gizmoClipSpace =
        projectionMatrix * viewMatrix * Vector4(gizmoWorldPos.x, gizmoWorldPos.y, gizmoWorldPos.z, 1.0);

    var gizmoNdc = gizmoClipSpace / gizmoClipSpace.w;
    final gizmoScreenSpace = Vector2(
      ((gizmoNdc.x / 2) + 0.5) * viewport.width.toDouble(),
      viewport.height.toDouble() - (((gizmoNdc.y / 2) + 0.5) * viewport.height.toDouble()),
    );

    final startAngle = math.atan2(_dragStartScreen!.y - gizmoScreenSpace.y, _dragStartScreen!.x - gizmoScreenSpace.x);
    final currentAngle = math.atan2(currentScreen.y - gizmoScreenSpace.y, currentScreen.x - gizmoScreenSpace.x);

    // Update current marker position on the ring
    if (_currentMarker != null) {
      final currentPos = await _getMarkerPositionOnRing(screenX, screenY, _activeAxis, context: ctx);
      if (currentPos != null && !_isDisposed) {
        await _updateMarkerPosition(_currentMarker!, currentPos);
      }
    }

    var angleDelta = currentAngle - startAngle;
    final axisVector = _getAxisVector(_activeAxis);
    final toCamera = (cameraPosition - gizmoWorldPos).normalized();
    final dot = axisVector.dot(toCamera);

    if (dot < 0) {
      angleDelta = -angleDelta;
    }

    final axisRotation = Quaternion.axisAngle(axisVector, angleDelta);
    final startRotation = Quaternion.fromRotation(_targetStartTransform!.getRotation());
    final newRotation = axisRotation * startRotation;

    final scaleX = math.sqrt(
      _targetStartTransform![0] * _targetStartTransform![0] +
          _targetStartTransform![1] * _targetStartTransform![1] +
          _targetStartTransform![2] * _targetStartTransform![2],
    );
    final scaleY = math.sqrt(
      _targetStartTransform![4] * _targetStartTransform![4] +
          _targetStartTransform![5] * _targetStartTransform![5] +
          _targetStartTransform![6] * _targetStartTransform![6],
    );
    final scaleZ = math.sqrt(
      _targetStartTransform![8] * _targetStartTransform![8] +
          _targetStartTransform![9] * _targetStartTransform![9] +
          _targetStartTransform![10] * _targetStartTransform![10],
    );

    final startScale = Vector3(scaleX, scaleY, scaleZ);
    final newWorldTransform = Matrix4.compose(gizmoWorldPos, newRotation, startScale);

    // Store the computed world transform for the callback to use
    _lastComputedWorldTransform = newWorldTransform;

    if (_attachedTarget != null && !_isDisposed) {
      // Convert world transform to local transform for proper hierarchy handling
      final localTransform = _worldToLocalTransform(_attachedTarget!, newWorldTransform);
      await viewer.app.setTransform(_attachedTarget!, localTransform);
    }
  }

  /// Converts a world transform to a local transform for the given entity.
  /// Takes into account the entity's parent hierarchy.
  Matrix4 _worldToLocalTransform(ThermionEntity entity, Matrix4 worldTransform) {
    final tm = viewer.app.transformManager;
    final parent = tm.getParent(entity);

    if (parent == null) {
      // No parent, local == world
      return worldTransform;
    }

    // local = parent_world_inverse * world
    final parentWorld = tm.getWorldTransform(parent);
    final parentWorldInverse = parentWorld.clone()..invert();
    return parentWorldInverse * worldTransform;
  }

  Future<void> endDrag() async {
    if (_type == TransformationGizmoType.rotation && !_isDisposed) {
      await _hideMarkers();
    }

    _activeAxis = GizmoAxis.none;
    _dragStartScreen = null;
    _targetStartTransform = null;
    _lastComputedWorldTransform = null;

    if (!_isDisposed) {
      await _updateHighlights();
    }
  }

  Future<void> endDragAndRehover(int screenX, int screenY) async {
    if (_type == TransformationGizmoType.rotation && !_isDisposed) {
      await _hideMarkers();
    }

    _activeAxis = GizmoAxis.none;
    _dragStartScreen = null;
    _targetStartTransform = null;
    _lastComputedWorldTransform = null;

    if (_isDisposed) return;

    _hoveredAxis = await pickAxis(screenX, screenY);
    if (!_isDisposed) {
      await _updateHighlights();
    }
  }

  Vector3 _getAxisVector(GizmoAxis axis) {
    switch (axis) {
      case GizmoAxis.x:
        return Vector3(1, 0, 0);
      case GizmoAxis.y:
        return Vector3(0, 1, 0);
      case GizmoAxis.z:
        return Vector3(0, 0, 1);
      default:
        return Vector3.zero();
    }
  }

  /// Get marker position on ring by projecting ring points to screen space
  /// and finding the closest point to the mouse cursor.
  Future<Vector3?> _getMarkerPositionOnRing(
    int screenX,
    int screenY,
    GizmoAxis axis, {
    GizmoCameraContext? context,
  }) async {
    if (_isDisposed || _rootEntity == null) return null;

    final ctx = context ?? await GizmoCameraContext.fetch(viewer);
    if (_isDisposed) return null;

    // Get gizmo world position and scale
    final gizmoTransform = await viewer.app.transformManager.getWorldTransform(_rootEntity!);
    final gizmoWorldPos = gizmoTransform.getTranslation();
    final gizmoScale = gizmoTransform.getColumn(0).xyz.length;

    if (_isDisposed) return null;

    // Project a point from local ring space to screen space
    Vector2 projectToScreen(Vector3 localPos) {
      final worldPos = gizmoWorldPos + localPos * gizmoScale;
      return ctx.projectToScreen(worldPos);
    }

    // Distance from point to line segment in 2D
    double pointToSegmentDistance(Vector2 p, Vector2 a, Vector2 b) {
      final ab = b - a;
      final ap = p - a;
      final t = (ap.dot(ab) / ab.dot(ab)).clamp(0.0, 1.0);
      final closest = a + ab * t;
      return (p - closest).length;
    }

    // Get basis vectors for the ring's orientation in local space
    Vector3 basis1, basis2;
    switch (axis) {
      case GizmoAxis.x:
        basis1 = Vector3(0, 1, 0);
        basis2 = Vector3(0, 0, 1);
        break;
      case GizmoAxis.y:
        basis1 = Vector3(1, 0, 0);
        basis2 = Vector3(0, 0, 1);
        break;
      case GizmoAxis.z:
        basis1 = Vector3(1, 0, 0);
        basis2 = Vector3(0, 1, 0);
        break;
      default:
        return null;
    }

    final mousePos = Vector2(screenX.toDouble(), screenY.toDouble());

    // Sample points around the ring and find the closest one
    const sampleCount = 64;
    double minDist = double.infinity;
    Vector3? closestLocalPos;

    for (int i = 0; i < sampleCount; i++) {
      final angle1 = (i / sampleCount) * 2 * math.pi;
      final angle2 = ((i + 1) % sampleCount / sampleCount) * 2 * math.pi;

      // Get two consecutive points on the ring in local space
      final localPos1 = (basis1 * math.cos(angle1) + basis2 * math.sin(angle1)) * _ringRadius;
      final localPos2 = (basis1 * math.cos(angle2) + basis2 * math.sin(angle2)) * _ringRadius;

      // Project to screen space
      final screenPos1 = projectToScreen(localPos1);
      final screenPos2 = projectToScreen(localPos2);

      // Check distance to this segment
      final dist = pointToSegmentDistance(mousePos, screenPos1, screenPos2);

      if (dist < minDist) {
        minDist = dist;
        // Return the first point of the closest segment
        closestLocalPos = localPos1;
      }
    }

    return closestLocalPos;
  }

  Future<void> _createMarkers() async {
    if (_isDisposed) return;

    final markerGeom = _createSphereGeometry(_markerRadius, 12, 8);

    // Start marker (white)
    _startMarkerAsset = await viewer.app.createGeometry(markerGeom, materialInstances: [_whiteMat!]);
    if (!await _takeAssetOwnership(_startMarkerAsset!)) return;
    _startMarker = _startMarkerAsset!.entity;

    // Current marker (yellow)
    _currentMarkerAsset = await viewer.app.createGeometry(markerGeom, materialInstances: [_yellowMat!]);
    if (!await _takeAssetOwnership(_currentMarkerAsset!)) return;
    _currentMarker = _currentMarkerAsset!.entity;

    // Parent to root entity
    if (_rootEntity != null) {
      viewer.app.transformManager.setParent(_startMarker!, _rootEntity!);
      viewer.app.transformManager.setParent(_currentMarker!, _rootEntity!);
    }

    // Draw on top of the rings (set once here; the priority never changes,
    // so it must not be re-set on every marker move).
    await viewer.app.setPriority(_startMarker!, 7);
    if (_isDisposed) return;
    await viewer.app.setPriority(_currentMarker!, 7);

    // Initially hide markers
    await _hideMarkers();
  }

  Future<void> _hideMarkers() async {
    if (_isDisposed) return;

    // Hide by scaling to zero
    final hideTransform = Matrix4.compose(Vector3.zero(), Quaternion.identity(), Vector3.zero());

    if (_startMarker != null) {
      await viewer.app.setTransform(_startMarker!, hideTransform);
    }
    if (_currentMarker != null) {
      await viewer.app.setTransform(_currentMarker!, hideTransform);
    }
  }

  Future<void> _updateMarkerPosition(ThermionEntity marker, Vector3 localPosition) async {
    if (_isDisposed) return;

    final markerTransform = Matrix4.compose(localPosition, Quaternion.identity(), Vector3.all(1.0));
    await viewer.app.setTransform(marker, markerTransform);
  }

  Future<void> _updateHighlights() async {
    if (_isDisposed) return;
    for (final axis in [GizmoAxis.x, GizmoAxis.y, GizmoAxis.z]) {
      final isActive = axis == _activeAxis;
      final isHovered = axis == _hoveredAxis;
      final alpha = isActive ? 1.0 : (isHovered ? 0.75 : 0.5);

      if (_isDisposed) return;

      switch (axis) {
        case GizmoAxis.x:
          await _redMat?.setParameterFloat4("baseColorFactor", 1.0, 0.0, 0.0, alpha);
          break;
        case GizmoAxis.y:
          await _greenMat?.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, alpha);
          break;
        case GizmoAxis.z:
          await _blueMat?.setParameterFloat4("baseColorFactor", 0.0, 0.0, 1.0, alpha);
          break;
        default:
          break;
      }
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true; // Set flag immediately

    // Destroy the geometry assets (also removes them from the scene and
    // frees their native vertex/index buffers).
    for (final asset in _assets) {
      await viewer.destroyAsset(asset);
    }
    _assets.clear();

    // Destroy root entity (its children are gone by now).
    if (_rootEntity != null) {
      await viewer.app.destroyEntity(_rootEntity!);
      _rootEntity = null;
    }

    // Destroy material instances.
    await _redMat?.destroy();
    await _greenMat?.destroy();
    await _blueMat?.destroy();
    await _whiteMat?.destroy();
    await _yellowMat?.destroy();

    _startMarker = null;
    _currentMarker = null;
    _startMarkerAsset = null;
    _currentMarkerAsset = null;

    _redMat = null;
    _greenMat = null;
    _blueMat = null;
    _whiteMat = null;
    _yellowMat = null;

    _attachedTarget = null;
    _activeAxis = GizmoAxis.none;
    _hoveredAxis = GizmoAxis.none;
    _dragStartScreen = null;
    _targetStartTransform = null;
    _lastComputedWorldTransform = null;
    _lastRootTransform = null;
  }
}
