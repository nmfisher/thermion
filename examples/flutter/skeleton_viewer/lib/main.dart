import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/input/input.dart';
import 'package:thermion_dart/src/input/src/implementations/fixed_orbit_camera_delegate_v2.dart';
import 'package:thermion_dart/src/input/src/implementations/gizmo_attachment_delegate.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter/src/widgets/src/pixel_ratio_aware.dart';

void main() {
  runApp(const SkeletonViewerApp());
}

class SkeletonViewerApp extends StatelessWidget {
  const SkeletonViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skeleton Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SkeletonViewerPage(),
    );
  }
}

class SkeletonViewerPage extends StatefulWidget {
  const SkeletonViewerPage({super.key});

  @override
  State<SkeletonViewerPage> createState() => _SkeletonViewerPageState();
}

class _SkeletonViewerPageState extends State<SkeletonViewerPage> {
  ThermionViewer? viewer;
  ThermionAsset? asset;
  DelegateInputHandler? inputHandler;
  BoneVisualizer? _boneVisualizer;
  GizmoAttachmentDelegate? _gizmoDelegate;

  bool _isLoading = true;
  bool _showSkeleton = true;
  bool _showMesh = true;
  List<String> _gltfBoneNames = [];
  List<String> _boneNames = [];
  int? _selectedBoneIndex;
  AttachmentTarget? _currentTarget;
  TransformationGizmoType _gizmoType = TransformationGizmoType.rotation;

  /// Interaction mode: 'pose' for bone manipulation, 'object' for mesh manipulation
  String _interactionMode = 'pose';

  // Visualization settings
  double _sphereRadius = 0.03;
  double _envelopeRadius = 0.025;

  // Input tracking
  bool _isMiddleButtonDown = false;
  bool _isPanning = false;
  Vector2? _lastPanPosition;

  // Runtime skinned asset state
  static const double _runtimeOffsetX = 3.0;
  bool _hasRuntimeAsset = false;
  ThermionEntity? _runtimeRenderableEntity;
  ThermionEntity? _runtimeBone0;
  ThermionEntity? _runtimeBone1;
  ThermionAsset? _runtimeBone0Viz;
  ThermionAsset? _runtimeBone1Viz;
  ThermionAsset? _runtimeEnvelopeViz;
  late final Matrix4 _bone0RestPose;
  late final Matrix4 _bone1RestPose;

  bool get _isRuntimeBone =>
      _currentTarget?.boneIndex != null &&
      _currentTarget!.boneIndex! >= _gltfBoneNames.length;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      ThermionFlutterPlugin.instance.setOptions(const ThermionFlutterOptions(
          webOptions: WebOptions(importCanvasAsWidget: false)));
    }
    _initialize();
  }

  Future<void> _initialize() async {
    viewer = await ThermionFlutterPlugin.createViewer();

    // Load armature model
    final assetData = await rootBundle.load('assets/cube_with_morph_targets.glb');
    asset = await viewer!.loadGltfFromBuffer(
      assetData.buffer.asUint8List(),
    );
    await viewer!.addToScene(asset!);

    // Get bone names
    _gltfBoneNames = await asset!.getBoneNames();
    _boneNames = List.from(_gltfBoneNames);

    // Create bone visualizer
    _boneVisualizer = BoneVisualizer(
      viewer: viewer!,
      asset: asset!,
      skinIndex: 0,
      sphereRadius: _sphereRadius,
      envelopeRadius: _envelopeRadius,
    );
    await _boneVisualizer!.show();

    // Camera setup
    final camera = await viewer!.getActiveCamera();
    await camera.lookAt(
      Vector3(4, 3, 8),
      focus: Vector3(1.5, 1, 0),
      up: Vector3(0, 1, 0),
    );

    // Lighting
    await viewer!.addDirectLight(DirectLight.sun(
        direction: Vector3(0.7, -1, -0.8).normalized(), intensity: 100000.0));

    // Set up gizmo delegate for bone posing
    _gizmoDelegate = GizmoAttachmentDelegate(
      viewer: viewer!,
      view: viewer!.view,
      gizmoType: _gizmoType,
      bonePickStrategy: BonePickStrategy.explicit,
      allowGizmoOnly: true,
      onAttached: (target) async {
        setState(() {
          _currentTarget = target;
          _selectedBoneIndex = target.boneIndex;
        });
        if (!_isRuntimeBone) {
          await _boneVisualizer?.highlightBone(target.boneIndex);
        }
      },
      onDetached: () async {
        setState(() {
          _currentTarget = null;
          _selectedBoneIndex = null;
        });
        await _boneVisualizer?.highlightBone(null);
      },
      onTransformChanged: (transform) async {
        if (_isRuntimeBone) {
          await _updateRuntimeBoneVisualization();
          await _updateRuntimeSkinning();
        } else {
          await _boneVisualizer?.update();
          if (_currentTarget?.isBone == true && asset != null) {
            await FilamentApp.instance!.animationManager.updateBoneMatrices(asset!);
          }
        }
      },
    );

    // Set up input handler with chained delegates (gizmo first, then orbit)
    inputHandler = DelegateInputHandler(
      viewer: viewer!,
      delegate: ChainedDelegate([
        _gizmoDelegate!,
        OrbitInputHandlerDelegate(viewer!.view),
      ]),
    );

    // Create runtime skinned asset alongside glTF
    await _createRuntimeSkinnedAsset();
    _hasRuntimeAsset = true;
    _rebuildBoneNames();

    await viewer!.setBackgroundColor(0.15, 0.15, 0.18, 1.0);
    await viewer!.setPostProcessing(true);
    await viewer!.setRendering(true);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _toggleSkeleton() async {
    if (_showSkeleton) {
      await _boneVisualizer?.hide();
      for (final viz in [_runtimeBone0Viz, _runtimeBone1Viz, _runtimeEnvelopeViz]) {
        if (viz != null) await viewer!.removeFromScene(viz);
      }
    } else {
      await _boneVisualizer?.show();
      for (final viz in [_runtimeBone0Viz, _runtimeBone1Viz, _runtimeEnvelopeViz]) {
        if (viz != null) await viewer!.addToScene(viz);
      }
    }
    setState(() {
      _showSkeleton = !_showSkeleton;
    });
  }

  Future<void> _toggleMesh() async {
    if (asset == null) return;

    if (_showMesh) {
      await viewer!.removeFromScene(asset!);
      if (_runtimeRenderableEntity != null) {
        final scene = await viewer!.view.getScene();
        await scene.removeEntity(_runtimeRenderableEntity!);
      }
    } else {
      await viewer!.addToScene(asset!);
      if (_runtimeRenderableEntity != null) {
        final scene = await viewer!.view.getScene();
        await scene.addEntity(_runtimeRenderableEntity!);
      }
    }
    setState(() {
      _showMesh = !_showMesh;
    });
  }

  void _rebuildBoneNames() {
    _boneNames = List.from(_gltfBoneNames);
    if (_hasRuntimeAsset) {
      _boneNames.addAll(['[Runtime] Bone0', '[Runtime] Bone1']);
    }
  }

  Future<void> _createRuntimeSkinnedAsset() async {
    final app = FilamentApp.instance!;
    final rm = app.renderableManager;
    final tm = app.transformManager;
    const ox = _runtimeOffsetX;

    // Create bone entities, offset by ox
    _runtimeBone0 = await app.createEntity();
    _bone0RestPose = Matrix4.translation(Vector3(ox, 0, 0));
    tm.setTransform(_runtimeBone0!, _bone0RestPose);

    _runtimeBone1 = await app.createEntity();
    _bone1RestPose = Matrix4.translation(Vector3(ox, 2, 0));
    tm.setTransform(_runtimeBone1!, Matrix4.translation(Vector3(0, 2, 0)));
    tm.setParent(_runtimeBone1!, _runtimeBone0!);

    // Two cubes merged into one skinned mesh, offset by ox
    const vertsPerCube = 8;
    const totalVerts = vertsPerCube * 2;
    const indicesPerCube = 36;
    const totalIndices = indicesPerCube * 2;

    final cubeVerts = Float32List.fromList([
      -0.5, -0.5, -0.5,  0.5, -0.5, -0.5,
      -0.5,  0.5, -0.5,  0.5,  0.5, -0.5,
      -0.5, -0.5,  0.5,  0.5, -0.5,  0.5,
      -0.5,  0.5,  0.5,  0.5,  0.5,  0.5,
    ]);

    final cubeIdx = Uint16List.fromList([
      4, 5, 7, 4, 7, 6, // front
      1, 0, 2, 1, 2, 3, // back
      2, 6, 7, 2, 7, 3, // top
      0, 1, 5, 0, 5, 4, // bottom
      1, 3, 7, 1, 7, 5, // right
      0, 4, 6, 0, 6, 2, // left
    ]);

    final positions = Float32List(totalVerts * 3);
    final boneIndices = Uint8List(totalVerts * 4);
    final boneWeights = Float32List(totalVerts * 4);
    final indices = Uint16List(totalIndices);

    for (int i = 0; i < vertsPerCube; i++) {
      // Cube 1 offset by ox
      positions[i * 3]     = cubeVerts[i * 3] + ox;
      positions[i * 3 + 1] = cubeVerts[i * 3 + 1];
      positions[i * 3 + 2] = cubeVerts[i * 3 + 2];
      boneIndices[i * 4] = 0;
      boneWeights[i * 4] = 1.0;

      // Cube 2 offset by ox and y+2
      final j = vertsPerCube + i;
      positions[j * 3]     = cubeVerts[i * 3] + ox;
      positions[j * 3 + 1] = cubeVerts[i * 3 + 1] + 2.0;
      positions[j * 3 + 2] = cubeVerts[i * 3 + 2];
      boneIndices[j * 4] = 1;
      boneWeights[j * 4] = 1.0;
    }

    for (int i = 0; i < indicesPerCube; i++) {
      indices[i] = cubeIdx[i];
      indices[indicesPerCube + i] = cubeIdx[i] + vertsPerCube;
    }

    final vertexBuffer = await (rm.createVertexBufferBuilder()
      ..bufferCount(3)
      ..vertexCount(totalVerts)
      ..attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3)
      ..attribute(VertexAttribute.BONE_INDICES, 1, VertexAttributeType.UBYTE4)
      ..attribute(VertexAttribute.BONE_WEIGHTS, 2, VertexAttributeType.FLOAT4))
    .build();

    await vertexBuffer.setBufferAt(0, positions);
    await vertexBuffer.setBufferAt(1, boneIndices);
    await vertexBuffer.setBufferAt(2, boneWeights);

    final indexBuffer = await (rm.createIndexBufferBuilder()
      ..indexCount(totalIndices)
      ..bufferType(IndexType.USHORT))
    .build();
    await indexBuffer.setBuffer(indices);

    final material = await app.createUnlitMaterialInstance();
    await material.setParameterFloat4("baseColorFactor", 0.3, 0.6, 0.9, 1.0);
    await material.setCullingMode(CullingMode.NONE);

    _runtimeRenderableEntity = await app.createEntity();

    final builder = rm.createBuilder(1)
      ..boundingBox(Aabb3.minMax(
        Vector3(ox - 0.5, -0.5, -0.5),
        Vector3(ox + 0.5, 2.5 + 0.5, 0.5),
      ))
      ..geometry(0, PrimitiveType.TRIANGLES, vertexBuffer, indexBuffer, 0, totalIndices)
      ..material(0, material)
      ..skinning(2, [Matrix4.identity(), Matrix4.identity()]);

    await builder.build(_runtimeRenderableEntity!);

    final scene = await viewer!.view.getScene();
    await scene.addEntity(_runtimeRenderableEntity!);

    // Bone visualization using overlay material + priority 7 (renders on top)
    final boneOverlayMat = await app.createBoneOverlayMaterial();
    final jointColor = Vector4(1.0, 1.0, 0.0, 1.0); // yellow
    final envelopeColor = Vector4(0.3, 0.8, 1.0, 1.0); // light blue
    const jointRadius = 0.03;
    const envelopeRadius = 0.025;

    final sphereGeom = GeometryHelper.sphere(normals: true, uvs: false);
    final cylinderGeom = GeometryHelper.cylinder(radius: 1.0, length: 1.0, normals: true, uvs: false);

    // Joint sphere at bone0 (head)
    final joint0Inst = await boneOverlayMat.createInstance();
    await joint0Inst.setParameterFloat4("baseColorFactor",
        jointColor.r, jointColor.g, jointColor.b, jointColor.a);
    _runtimeBone0Viz = await viewer!.createGeometry(
      sphereGeom, materialInstances: [joint0Inst],
    );
    tm.setTransform(_runtimeBone0Viz!.entity,
      Matrix4.compose(Vector3(ox, 0, 0), Quaternion.identity(), Vector3.all(jointRadius)));
    await app.setPriority(_runtimeBone0Viz!.entity, 7);

    // Joint sphere at bone1 (tail / child joint)
    final joint1Inst = await boneOverlayMat.createInstance();
    await joint1Inst.setParameterFloat4("baseColorFactor",
        jointColor.r, jointColor.g, jointColor.b, jointColor.a);
    _runtimeBone1Viz = await viewer!.createGeometry(
      sphereGeom, materialInstances: [joint1Inst],
    );
    tm.setTransform(_runtimeBone1Viz!.entity,
      Matrix4.compose(Vector3(ox, 2, 0), Quaternion.identity(), Vector3.all(jointRadius)));
    await app.setPriority(_runtimeBone1Viz!.entity, 7);

    // Cylinder connecting bone0 head to bone1 head
    final envelopeInst = await boneOverlayMat.createInstance();
    await envelopeInst.setParameterFloat4("baseColorFactor",
        envelopeColor.r, envelopeColor.g, envelopeColor.b, envelopeColor.a);
    _runtimeEnvelopeViz = await viewer!.createGeometry(
      cylinderGeom, materialInstances: [envelopeInst],
    );
    _setRuntimeEnvelopeTransform(Vector3(ox, 0, 0), Vector3(ox, 2, 0), envelopeRadius);
    await app.setPriority(_runtimeEnvelopeViz!.entity, 7);
  }

  void _setRuntimeEnvelopeTransform(Vector3 head, Vector3 tail, double radius) {
    if (_runtimeEnvelopeViz == null) return;
    final tm = FilamentApp.instance!.transformManager;
    final delta = tail - head;
    final length = delta.length;
    final direction = delta.normalized();
    final rotation = Quaternion.fromTwoVectors(Vector3(0, 1, 0), direction);
    final midpoint = head + direction * (length / 2);
    tm.setTransform(_runtimeEnvelopeViz!.entity,
      Matrix4.compose(midpoint, rotation, Vector3(radius, length, radius)));
  }

  Future<void> _cleanupRuntimeAsset() async {
    final scene = await viewer!.view.getScene();
    if (_runtimeRenderableEntity != null) {
      await scene.removeEntity(_runtimeRenderableEntity!);
    }
    for (final viz in [_runtimeBone0Viz, _runtimeBone1Viz, _runtimeEnvelopeViz]) {
      if (viz != null) {
        await viewer!.removeFromScene(viz);
        await viewer!.destroyAsset(viz);
      }
    }
    _runtimeRenderableEntity = null;
    _runtimeBone0 = null;
    _runtimeBone1 = null;
    _runtimeBone0Viz = null;
    _runtimeBone1Viz = null;
    _runtimeEnvelopeViz = null;
  }

  Future<void> _updateRuntimeBoneVisualization() async {
    if (_runtimeBone0 == null || _runtimeBone1 == null) return;
    final tm = FilamentApp.instance!.transformManager;

    final pos0 = tm.getWorldTransform(_runtimeBone0!).getTranslation();
    final pos1 = tm.getWorldTransform(_runtimeBone1!).getTranslation();

    if (_runtimeBone0Viz != null) {
      tm.setTransform(_runtimeBone0Viz!.entity,
        Matrix4.compose(pos0, Quaternion.identity(), Vector3.all(0.03)));
    }
    if (_runtimeBone1Viz != null) {
      tm.setTransform(_runtimeBone1Viz!.entity,
        Matrix4.compose(pos1, Quaternion.identity(), Vector3.all(0.03)));
    }
    _setRuntimeEnvelopeTransform(pos0, pos1, 0.025);
  }

  Future<void> _updateRuntimeSkinning() async {
    if (_runtimeRenderableEntity == null || _runtimeBone0 == null || _runtimeBone1 == null) return;
    final tm = FilamentApp.instance!.transformManager;
    final rm = FilamentApp.instance!.renderableManager;

    final bone0World = tm.getWorldTransform(_runtimeBone0!);
    final bone1World = tm.getWorldTransform(_runtimeBone1!);

    // setBones expects the final matrix (world * inverseBind), same as
    // Filament's Animator::updateBoneMatrices computes for glTF assets.
    final bone0Final = bone0World * Matrix4.inverted(_bone0RestPose);
    final bone1Final = bone1World * Matrix4.inverted(_bone1RestPose);

    await rm.setBonesFromMat4(_runtimeRenderableEntity!, [bone0Final, bone1Final]);
  }

  /// Pick a runtime bone using screen-space distance (bypasses depth buffer).
  Future<int?> _pickRuntimeBoneAtScreen(int screenX, int screenY, {double threshold = 30.0}) async {
    if (_runtimeBone0 == null || _runtimeBone1 == null) return null;

    final view = viewer!.view;
    final camera = await view.getCamera();
    final viewport = await view.getViewport();
    final projMatrix = await camera.getProjectionMatrix();
    final viewMatrix = await camera.getViewMatrix();
    final tm = FilamentApp.instance!.transformManager;

    final mousePos = Vector2(screenX.toDouble(), screenY.toDouble());

    Vector2 project(Vector3 worldPos) {
      final clip = projMatrix * viewMatrix * Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
      final ndc = clip / clip.w;
      return Vector2(
        ((ndc.x + 1.0) / 2.0) * viewport.width.toDouble(),
        ((1.0 - ndc.y) / 2.0) * viewport.height.toDouble(),
      );
    }

    final pos0 = tm.getWorldTransform(_runtimeBone0!).getTranslation();
    final pos1 = tm.getWorldTransform(_runtimeBone1!).getTranslation();
    final screen0 = project(pos0);
    final screen1 = project(pos1);

    final d0 = (mousePos - screen0).length;
    final d1 = (mousePos - screen1).length;

    if (d0 < d1 && d0 < threshold) return 0;
    if (d1 < threshold) return 1;
    return null;
  }

  Future<void> _recreateVisualizer() async {
    if (asset == null) return;

    // Hide current visualizer
    await _boneVisualizer?.hide();

    // Create new visualizer with updated settings
    _boneVisualizer = BoneVisualizer(
      viewer: viewer!,
      asset: asset!,
      skinIndex: 0,
      sphereRadius: _sphereRadius,
      envelopeRadius: _envelopeRadius,
    );

    if (_showSkeleton) {
      await _boneVisualizer!.show();
    }
    setState(() {});
  }

  Future<void> _switchGizmoType(TransformationGizmoType type) async {
    if (_gizmoType == type) return;
    _gizmoType = type;
    await _gizmoDelegate?.setGizmoType(type);
    setState(() {});
  }

  Future<void> _panCamera(double deltaX, double deltaY) async {
    if (viewer == null) return;
    final camera = await viewer!.getActiveCamera();
    final modelMatrix = await camera.getModelMatrix();

    // Get camera right and up vectors from model matrix
    final right = Vector3(modelMatrix[0], modelMatrix[1], modelMatrix[2]);
    final up = Vector3(modelMatrix[4], modelMatrix[5], modelMatrix[6]);

    // Calculate pan offset
    final panOffset = right * deltaX + up * deltaY;

    // Translate camera
    final position = modelMatrix.getTranslation();
    final newPosition = position + panOffset;
    modelMatrix.setTranslation(newPosition);

    await camera.setModelMatrix(modelMatrix);
  }

  Future<void> _switchInteractionMode(String mode) async {
    if (_interactionMode == mode) return;
    _interactionMode = mode;
    // Detach current gizmo when switching modes
    await _gizmoDelegate?.detach();
    await _boneVisualizer?.highlightBone(null);
    setState(() {
      _currentTarget = null;
      _selectedBoneIndex = null;
    });
  }

  /// Handle picking when user clicks
  Future<void> _handlePick(int x, int y) async {
    if (viewer == null || asset == null) return;

    if (_interactionMode == 'pose') {
      // Try runtime bone picking first (screen-space distance, like BoneVisualizer)
      if (_hasRuntimeAsset) {
        final runtimeIdx = await _pickRuntimeBoneAtScreen(x, y);
        if (runtimeIdx != null) {
          final gltfCount = _gltfBoneNames.length;
          final boneEntity = runtimeIdx == 0 ? _runtimeBone0 : _runtimeBone1;
          await _gizmoDelegate?.attachTo(AttachmentTarget(
            entity: boneEntity!, boneIndex: gltfCount + runtimeIdx, skinIndex: 0,
          ));
          return;
        }
      }

      // Fall through to glTF bone picking
      if (_boneVisualizer == null) return;

      final boneIndex = await _boneVisualizer!.pickBoneAtScreen(x, y);
      if (boneIndex != null) {
        final boneEntity = _boneVisualizer!.getBoneEntity(boneIndex);
        if (boneEntity != null) {
          await _gizmoDelegate?.attachTo(AttachmentTarget(
            entity: boneEntity,
            asset: asset!,
            boneIndex: boneIndex,
            skinIndex: 0,
          ));
        }
      } else {
        // Clicked away from any bone - detach gizmo
        await _gizmoDelegate?.detach();
      }
    } else {
      // Object mode: use depth-buffer picking for mesh
      await viewer!.view.pick(x, y, (result) async {
        if (result.entity == 0) {
          await _gizmoDelegate?.detach();
          return;
        }
        // Check if it's NOT a bone visualization entity
        final boneIndex = _boneVisualizer?.getBoneIndexForEntity(result.entity);
        if (boneIndex == null) {
          // It's a renderable entity, not a bone visualization
          await _gizmoDelegate?.attachTo(AttachmentTarget.entity(result.entity));
        }
      });
    }
  }

  Future<void> _attachToBoneFromList(int boneIndex) async {
    final gltfCount = _gltfBoneNames.length;

    if (boneIndex >= gltfCount) {
      // Runtime bone
      final runtimeIndex = boneIndex - gltfCount;
      final boneEntity = runtimeIndex == 0 ? _runtimeBone0 : _runtimeBone1;
      if (boneEntity != null) {
        await _gizmoDelegate?.attachTo(AttachmentTarget(
          entity: boneEntity, boneIndex: boneIndex, skinIndex: 0,
        ));
      }
      return;
    }

    // glTF bone
    if (asset == null || _boneVisualizer == null) return;

    final boneEntity = _boneVisualizer!.getBoneEntity(boneIndex);
    if (boneEntity != null) {
      await _gizmoDelegate?.attachTo(AttachmentTarget(
        entity: boneEntity,
        asset: asset!,
        boneIndex: boneIndex,
        skinIndex: 0,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    if (_isLoading || viewer == null) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text('Skeleton Viewer'),
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Skeleton Viewer'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Control panel
          Container(
            width: 280,
            color: Colors.grey[850],
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Interaction mode selector
                  const Text(
                    'Interaction Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _switchInteractionMode('pose'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          backgroundColor: _interactionMode == 'pose'
                              ? Colors.purple.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                        child: const Text('Pose',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _switchInteractionMode('object'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          backgroundColor: _interactionMode == 'object'
                              ? Colors.purple.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                        child: const Text('Object',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Visibility toggles
                  const Text(
                    'Visibility',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Show Skeleton',
                        style: TextStyle(color: Colors.white70)),
                    value: _showSkeleton,
                    onChanged: (_) => _toggleSkeleton(),
                    dense: true,
                  ),
                  SwitchListTile(
                    title: const Text('Show Mesh',
                        style: TextStyle(color: Colors.white70)),
                    value: _showMesh,
                    onChanged: (_) => _toggleMesh(),
                    dense: true,
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Visualization settings
                  const Text(
                    'Visualization Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Joint sphere radius
                  Text(
                    'Joint Sphere Radius: ${_sphereRadius.toStringAsFixed(3)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Slider(
                    value: _sphereRadius,
                    min: 0.01,
                    max: 0.1,
                    onChanged: (value) {
                      setState(() {
                        _sphereRadius = value;
                      });
                    },
                    onChangeEnd: (_) => _recreateVisualizer(),
                  ),

                  // Bone envelope radius
                  Text(
                    'Bone Envelope Radius: ${_envelopeRadius.toStringAsFixed(3)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Slider(
                    value: _envelopeRadius,
                    min: 0.005,
                    max: 0.05,
                    onChanged: (value) {
                      setState(() {
                        _envelopeRadius = value;
                      });
                    },
                    onChangeEnd: (_) => _recreateVisualizer(),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Gizmo mode selector
                  const Text(
                    'Gizmo Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            _switchGizmoType(TransformationGizmoType.translation),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          backgroundColor:
                              _gizmoType == TransformationGizmoType.translation
                                  ? Colors.blue.withValues(alpha: 0.5)
                                  : Colors.transparent,
                        ),
                        child: const Text('Translate',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () =>
                            _switchGizmoType(TransformationGizmoType.rotation),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          backgroundColor:
                              _gizmoType == TransformationGizmoType.rotation
                                  ? Colors.blue.withValues(alpha: 0.5)
                                  : Colors.transparent,
                        ),
                        child: const Text('Rotate',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                  if (_currentTarget != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Selected: ${_currentTarget!.boneIndex != null ? _boneNames[_currentTarget!.boneIndex!] : "Entity"}',
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Bone list
                  const Text(
                    'Bones',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_boneNames.isEmpty)
                    const Text(
                      'No bones found',
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _boneNames.length,
                      itemBuilder: (context, index) {
                        final isSelected = _selectedBoneIndex == index;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          title: Text(
                            '$index: ${_boneNames[index]}',
                            style: TextStyle(
                              color: isSelected ? Colors.amber : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => _attachToBoneFromList(index),
                        );
                      },
                    ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Instructions
                  const Text(
                    'Controls',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pose mode:\n'
                    '  • Click joint to select bone\n'
                    '  • Drag gizmo to pose\n'
                    'Object mode:\n'
                    '  • Click mesh to select\n'
                    'Camera:\n'
                    '  • Middle-drag to orbit\n'
                    '  • Shift+Middle-drag to pan\n'
                    '  • Scroll to zoom',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // 3D viewport
          Expanded(
            child: isDesktop ? _buildDesktop() : _buildMobile(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    return PixelRatioAware(builder: (ctx, pixelRatio) {
      return Listener(
        onPointerDown: (event) async {
          final x = (event.localPosition.dx * pixelRatio).toInt();
          final y = (event.localPosition.dy * pixelRatio).toInt();
          final localPosition = Vector2(x.toDouble(), y.toDouble());
          final delta = Vector2(
              event.delta.dx * pixelRatio, event.delta.dy * pixelRatio);

          if (event.buttons & kMiddleMouseButton != 0) {
            _isMiddleButtonDown = true;
            if (HardwareKeyboard.instance.isShiftPressed) {
              // Shift + Middle click - pan camera
              _isPanning = true;
              _lastPanPosition = localPosition;
            } else {
              // Middle click - orbit camera
              inputHandler?.handle(MouseEvent(
                MouseEventType.buttonDown,
                MouseButton.left, // Orbit delegate expects left button
                localPosition,
                delta,
              ));
            }
          } else if (event.buttons & kPrimaryMouseButton != 0) {
            // Left click - gizmo or joint selection
            // First check if we clicked on a gizmo axis (before processing event)
            final clickedGizmo = _gizmoDelegate?.gizmo != null
                ? await _gizmoDelegate!.gizmo!.pickAxis(x, y)
                : GizmoAxis.none;

            // Forward to input handler for gizmo drag processing
            inputHandler?.handle(MouseEvent(
              MouseEventType.buttonDown,
              MouseButton.left,
              localPosition,
              delta,
            ));

            // Only do bone picking if we didn't click on a gizmo axis
            if (clickedGizmo == GizmoAxis.none) {
              await _handlePick(x, y);
            }
          }
        },
        onPointerMove: (event) async {
          final localPosition = Vector2(
              event.localPosition.dx * pixelRatio,
              event.localPosition.dy * pixelRatio);

          if (_isPanning && _lastPanPosition != null) {
            // Pan the camera
            final delta = localPosition - _lastPanPosition!;
            _lastPanPosition = localPosition;
            await _panCamera(-delta.x * 0.01, delta.y * 0.01);
          } else if (_isMiddleButtonDown || _gizmoDelegate?.isDraggingGizmo == true) {
            // Forward move events for orbit or gizmo drag
            inputHandler?.handle(MouseEvent(
              MouseEventType.move,
              null,
              localPosition,
              Vector2(event.delta.dx * pixelRatio, event.delta.dy * pixelRatio),
            ));
          }
        },
        onPointerUp: (event) {
          final localPosition = Vector2(
              event.localPosition.dx * pixelRatio,
              event.localPosition.dy * pixelRatio);
          final delta = Vector2(
              event.delta.dx * pixelRatio, event.delta.dy * pixelRatio);

          _isMiddleButtonDown = false;
          _isPanning = false;
          _lastPanPosition = null;
          inputHandler?.handle(MouseEvent(
            MouseEventType.buttonUp,
            MouseButton.left,
            localPosition,
            delta,
          ));
        },
        onPointerSignal: (signal) {
          if (signal is PointerScrollEvent) {
            inputHandler?.handle(ScrollEvent(
              localPosition:
                  Vector2(signal.localPosition.dx, signal.localPosition.dy),
              delta: signal.scrollDelta.dy,
            ));
          }
        },
        child: ThermionWidget(viewer: viewer!),
      );
    });
  }

  Widget _buildMobile() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        inputHandler?.handle(MouseEvent(
          MouseEventType.buttonDown,
          MouseButton.left,
          Vector2(details.localPosition.dx, details.localPosition.dy),
          Vector2.zero(),
        ));
      },
      onPanUpdate: (details) {
        inputHandler?.handle(MouseEvent(
          MouseEventType.move,
          null,
          Vector2(details.localPosition.dx, details.localPosition.dy),
          Vector2(details.delta.dx, details.delta.dy),
        ));
      },
      onPanEnd: (details) {
        inputHandler?.handle(MouseEvent(
          MouseEventType.buttonUp,
          MouseButton.left,
          Vector2.zero(),
          Vector2.zero(),
        ));
      },
      child: ThermionWidget(viewer: viewer!),
    );
  }

  @override
  void dispose() {
    _boneVisualizer?.hide();
    if (_hasRuntimeAsset) {
      _cleanupRuntimeAsset();
    }
    inputHandler?.dispose();
    viewer?.dispose();
    super.dispose();
  }
}
