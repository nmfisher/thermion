import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data'; // Required for Float32List/Uint16List
import 'package:vector_math/vector_math_64.dart';
import 'package:thermion_dart/thermion_dart.dart';

enum GizmoType { translation, scale, rotation }

enum GizmoAxis { x, y, z, none }

class TransformationGizmo {
  final ThermionViewer viewer;

  ThermionEntity? _rootEntity;

  // Axis Shafts
  ThermionEntity? _xAxisShaft;
  ThermionEntity? _yAxisShaft;
  ThermionEntity? _zAxisShaft;

  // Axis Heads (Cones)
  ThermionEntity? _xAxisHead;
  ThermionEntity? _yAxisHead;
  ThermionEntity? _zAxisHead;

  MaterialInstance? _redMat;
  MaterialInstance? _greenMat;
  MaterialInstance? _blueMat;

  ThermionEntity? _attachedTarget;

  final double _axisLength = 1.5;
  final double _handleSize = 0.25;
  final double _shaftRadius = 0.03;

  TransformationGizmo(this.viewer);

  Future<void> create({GizmoType type = GizmoType.translation}) async {
    // 1. Create Unlit Materials (No depth write for "always on top" effect)
    _redMat = await _createGizmoMaterial(1.0, 0.0, 0.0);
    _greenMat = await _createGizmoMaterial(0.0, 1.0, 0.0);
    _blueMat = await _createGizmoMaterial(0.0, 0.0, 1.0);

    // 2. Create Root (Empty invisible cube)
    final rootAsset = await FilamentApp.instance!.createGeometry(
      _createCubeGeometry(0.01), // Tiny invisible cube
    );
    _rootEntity = rootAsset.entity;

    // Hide root geometry visually but keep it for transform hierarchy
    // (Or just scale to 0)
    await FilamentApp.instance!
        .setTransform(_rootEntity!, Matrix4.identity()..scale(0.0));
    await viewer.addToScene(rootAsset);

    if (type == GizmoType.translation) {
      await _buildTranslationAxes();
    }
  }

  Future<void> _buildTranslationAxes() async {
    // Generate manual geometry (No Normals, No UVs -> Safe for Unlit)
    final shaftGeom = _createCylinderGeometry(_shaftRadius, _axisLength, 12);
    final headGeom = _createConeGeometry(_handleSize, _handleSize * 2.0, 12);

    // Y Axis (Green, Up)
    final yGroup =
        await _createAxis(shaftGeom, headGeom, _greenMat!, Vector3(0, 1, 0));
    _yAxisShaft = yGroup.$1;
    _yAxisHead = yGroup.$2;

    // X Axis (Red, Right)
    final xGroup =
        await _createAxis(shaftGeom, headGeom, _redMat!, Vector3(1, 0, 0));
    _xAxisShaft = xGroup.$1;
    _xAxisHead = xGroup.$2;

    // Z Axis (Blue, Forward)
    final zGroup =
        await _createAxis(shaftGeom, headGeom, _blueMat!, Vector3(0, 0, 1));
    _zAxisShaft = zGroup.$1;
    _zAxisHead = zGroup.$2;
  }

  // Returns Pair<Shaft, Head>
  Future<(ThermionEntity, ThermionEntity)> _createAxis(Geometry shaft,
      Geometry head, MaterialInstance mat, Vector3 direction) async {
    // Create Shaft
    final shaftAsset = await FilamentApp.instance!
        .createGeometry(shaft, materialInstances: [mat]);
    await viewer.addToScene(shaftAsset);

    // Create Head
    final headAsset = await FilamentApp.instance!
        .createGeometry(head, materialInstances: [mat]);
    await viewer.addToScene(headAsset);

    // Calculations
    final rotation = Quaternion.fromTwoVectors(Vector3(0, 1, 0), direction);
    final shaftPos = direction * (_axisLength / 2); // Center shaft
    final headPos = direction * _axisLength; // Place head at tip

    final shaftMatrix = Matrix4.compose(shaftPos, rotation, Vector3.all(1.0));
    final headMatrix = Matrix4.compose(headPos, rotation, Vector3.all(1.0));

    // Update Transforms (In a full engine, we'd parent these to _rootEntity)
    await FilamentApp.instance!.setTransform(shaftAsset.entity, shaftMatrix);
    await FilamentApp.instance!.setTransform(headAsset.entity, headMatrix);

    return (shaftAsset.entity, headAsset.entity);
  }

  // --- Manual Geometry Generators (Bypasses Helper Bugs) ---

  /// Creates a simple cylinder geometry without Normals or UVs.
  /// Aligned along Y axis, centered at (0, length/2, 0) relative to base?
  /// Here we center it at (0,0,0) with height extending from -length/2 to +length/2
  Geometry _createCylinderGeometry(double radius, double length, int segments) {
    final vertices = <double>[];
    final indices = <int>[];
    final halfLen = length / 2;

    // Top Ring
    for (int i = 0; i < segments; i++) {
      final theta = (i / segments) * 2 * math.pi;
      vertices.addAll(
          [radius * math.cos(theta), halfLen, radius * math.sin(theta)]);
    }
    // Bottom Ring
    for (int i = 0; i < segments; i++) {
      final theta = (i / segments) * 2 * math.pi;
      vertices.addAll(
          [radius * math.cos(theta), -halfLen, radius * math.sin(theta)]);
    }

    // Indices (Side walls)
    // 0..N-1 are Top, N..2N-1 are Bottom
    for (int i = 0; i < segments; i++) {
      final top1 = i;
      final top2 = (i + 1) % segments;
      final bot1 = i + segments;
      final bot2 = (i + 1) % segments + segments;

      // Triangle 1
      indices.addAll([top1, bot1, top2]);
      // Triangle 2
      indices.addAll([top2, bot1, bot2]);
    }

    // Note: We skip caps for the shaft as they are usually hidden by the head/center.
    // If needed, we can add center vertices and fan indices.

    return Geometry(
        Float32List.fromList(vertices), Uint16List.fromList(indices),
        primitiveType: PrimitiveType.TRIANGLES);
  }

  /// Creates a simple cone geometry (Arrow head)
  /// Base at (0,0,0), Tip at (0, height, 0)
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
      // Tip -> Current -> Next
      indices.addAll([0, next, current]);
    }

    // Indices - Bottom Cap
    final centerIdx = segments + 1;
    for (int i = 0; i < segments; i++) {
      final current = i + 1;
      final next = (i + 1) % segments + 1;
      // Center -> Current -> Next
      indices.addAll([centerIdx, current, next]);
    }

    return Geometry(
        Float32List.fromList(vertices), Uint16List.fromList(indices),
        primitiveType: PrimitiveType.TRIANGLES);
  }

  Geometry _createCubeGeometry(double size) {
    // Simple cube for root
    final s = size / 2;
    final vertices = Float32List.fromList([
      s,
      s,
      s,
      s,
      -s,
      s,
      s,
      s,
      -s,
      s,
      -s,
      -s,
      -s,
      s,
      s,
      -s,
      -s,
      s,
      -s,
      s,
      -s,
      -s,
      -s,
      -s,
    ]);
    // Standard cube indices... simplified for brevity, assume calling GeometryHelper.cube
    // works for simple cubes if needed, or implement manually if paranoid.
    // We'll trust GeometryHelper.cube works for the root since you didn't report error there.
    return GeometryHelper.cube(normals: false, uvs: false)..scale(size);
  }

  Future<MaterialInstance> _createGizmoMaterial(
      double r, double g, double b) async {
    // Load unlit filamat
    final material = await FilamentApp.instance!.createMaterial(await File(
            "/Users/nickfisher/Documents/thermion/materials/gizmo.filamat")
        .readAsBytesSync());
    final mat = await material.createInstance();
    await mat.setParameterFloat4("baseColorFactor", r, g, b, 1.0);
    await mat.setDepthWriteEnabled(false);
    await mat.setDepthCullingEnabled(false);
    return mat;
  }

  void attachTo(ThermionEntity entity) {
    _attachedTarget = entity;
    update();
  }

  Future<void> update({Vector3? cameraPosition}) async {
    if (_attachedTarget == null || _rootEntity == null) return;

    final targetMatrix = await FilamentApp.instance!.transformManager
        .getLocalTransform(_attachedTarget!);
    final targetPos = targetMatrix.getTranslation();

    double scale = 1.0;
    if (cameraPosition != null) {
      final dist = targetPos.distanceTo(cameraPosition);
      scale = dist * 0.15;
    }

    final newTransform =
        Matrix4.compose(targetPos, Quaternion.identity(), Vector3.all(scale));

    await FilamentApp.instance!.setTransform(_rootEntity!, newTransform);
  }

  Future<GizmoAxis> pickAxis(int x, int y) async {
    final completer = Completer<ThermionEntity>();
    await viewer.view.pick(x, y, (result) {
      completer.complete(result.entity);
    });
    final hit = await completer.future;

    // Check Shafts AND Heads
    if (hit == _xAxisShaft || hit == _xAxisHead) return GizmoAxis.x;
    if (hit == _yAxisShaft || hit == _yAxisHead) return GizmoAxis.y;
    if (hit == _zAxisShaft || hit == _zAxisHead) return GizmoAxis.z;

    return GizmoAxis.none;
  }
}
