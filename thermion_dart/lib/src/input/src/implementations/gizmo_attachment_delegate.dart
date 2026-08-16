import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/viewer.dart';
import '../delegate_input_handler.dart';
import '../input_types.dart';
import '../../../utils/src/gizmos.dart';
import 'gizmo_attachment_types.dart';

/// Callback for when an entity or bone is selected for gizmo attachment.
typedef OnGizmoAttached = void Function(AttachmentTarget target);

/// Callback for when the gizmo transform changes during drag.
typedef OnGizmoTransformChanged = void Function(Matrix4 transform);

/// Strategy for selecting bones when clicking a skinned mesh.
enum BonePickStrategy {
  /// Find the bone nearest to the click point in world space.
  nearest,

  /// Don't auto-select bones; require explicit selection via API.
  explicit,
}

/// An [InputHandlerDelegate] that handles gizmo attachment and manipulation.
///
/// This delegate:
/// - Detects clicks on entities (via View.pick)
/// - Attaches a gizmo to the clicked entity or bone
/// - Handles gizmo drag interactions
/// - Can be chained with other delegates (e.g., orbit camera)
///
/// Example usage:
/// ```dart
/// final gizmoDelegate = GizmoAttachmentDelegate(
///   viewer: viewer,
///   view: viewer.view,
///   gizmoType: TransformationGizmoType.translation,
///   onAttached: (target) => print('Attached to $target'),
/// );
///
/// final inputHandler = DelegateInputHandler(
///   viewer: viewer,
///   delegate: ChainedDelegate([
///     gizmoDelegate,
///     OrbitInputHandlerDelegate(viewer.view),
///   ]),
///   batch: true,
/// );
/// ```
class GizmoAttachmentDelegate extends InputHandlerDelegate {
  final View view;
  final ThermionViewer viewer;

  // Configuration
  TransformationGizmoType gizmoType;
  final BonePickStrategy bonePickStrategy;
  final double bonePickThreshold; // Max world distance for "nearest" bone
  final bool allowGizmoOnly; // If true, can only pick gizmo axes

  // Callbacks
  final OnGizmoAttached? onAttached;
  final OnGizmoTransformChanged? onTransformChanged;
  final void Function()? onDetached;

  // State
  TransformationGizmo? _gizmo;
  AttachmentTarget? _currentTarget;
  bool _isGizmoInitialized = false;
  bool _isDraggingGizmo = false;

  // Raycast cache for bone picking
  ThermionEntity? _lastPickedEntity;
  Vector3? _lastPickWorldPosition;

  GizmoAttachmentDelegate({
    required this.viewer,
    required this.view,
    this.gizmoType = TransformationGizmoType.translation,
    this.bonePickStrategy = BonePickStrategy.nearest,
    this.bonePickThreshold = 0.5,
    this.allowGizmoOnly = false,
    this.onAttached,
    this.onTransformChanged,
    this.onDetached,
  });

  /// Get the gizmo instance (for external control).
  TransformationGizmo? get gizmo => _gizmo;

  /// Get the current attachment target.
  AttachmentTarget? get currentTarget => _currentTarget;

  /// Whether the gizmo is currently being dragged.
  bool get isDraggingGizmo => _isDraggingGizmo;

  /// Whether the gizmo is currently attached to a bone.
  bool get isAttachedToBone => _currentTarget?.isBone ?? false;

  /// While an axis drag is in progress, consume events so subsequent delegates
  /// in the chain (e.g. orbit camera) don't also react to them.
  @override
  bool get consumesEvents => _isDraggingGizmo;

  /// Initialize the gizmo (called automatically on first use).
  Future<void> _ensureGizmo() async {
    if (_isGizmoInitialized) return;
    _gizmo = TransformationGizmo(viewer);
    await _gizmo!.create(type: gizmoType);
    _isGizmoInitialized = true;
  }

  /// Explicitly attach to a target (bypasses picking).
  ///
  /// This is useful for:
  /// - Programmatic attachment
  /// - Explicit bone selection (when using BonePickStrategy.explicit)
  Future<void> attachTo(AttachmentTarget target) async {
    await _ensureGizmo();

    await _gizmo!.attachTo(target.entity);

    _currentTarget = target;
    onAttached?.call(target);
  }

  /// Detach the gizmo from the current target.
  Future<void> detach() async {
    await _gizmo?.detach();
    _currentTarget = null;
    onDetached?.call();
  }

  /// Get all bones for an asset (for explicit selection UI).
  ///
  /// Returns a list of [BoneInfo] containing bone names, indices, and entities.
  Future<List<BoneInfo>> getBones(ThermionAsset asset, {int skinIndex = 0}) async {
    final boneEntities = await asset.getBones(skinIndex: skinIndex);

    final bones = <BoneInfo>[];
    for (int i = 0; i < boneEntities.length; i++) {
      final boneEntity = boneEntities[i];
      final boneName = viewer.app.getNameForEntity(boneEntity) ?? 'Bone $i';
      bones.add(BoneInfo(name: boneName, index: i, entity: boneEntity, skinIndex: skinIndex));
    }
    return bones;
  }

  /// Change the gizmo type (translation/rotation).
  ///
  /// This disposes the current gizmo and creates a new one.
  Future<void> setGizmoType(TransformationGizmoType type) async {
    if (_isGizmoInitialized && _gizmo != null) {
      final oldTarget = _currentTarget;

      // Update gizmo type before recreating
      gizmoType = type;

      await _gizmo!.dispose();
      _gizmo = null;
      _isGizmoInitialized = false;

      // Recreate with new type
      await _ensureGizmo();
      if (oldTarget != null) {
        await attachTo(oldTarget);
      }
    }
  }

  @override
  Future<void> handle(List<InputEvent> events) async {
    await _ensureGizmo();

    for (final event in events) {
      switch (event) {
        case MouseEvent(type: MouseEventType.buttonDown, button: MouseButton.left || null, localPosition: final pos):
          final x = pos.x.toInt();
          final y = pos.y.toInt();

          // First check if gizmo axis was clicked
          final started = await _gizmo!.startDrag(x, y);
          if (started) {
            _isDraggingGizmo = true;
            _reportTransformChange();
          } else if (!allowGizmoOnly) {
            // If gizmo wasn't clicked, try to pick and attach to entity/bone
            await _pickAndAttach(x, y);
          }
          break;

        case MouseEvent(type: MouseEventType.buttonUp, button: MouseButton.left || null):
          if (_isDraggingGizmo) {
            await _gizmo!.endDrag();
            _isDraggingGizmo = false;
          }
          break;

        case MouseEvent(type: MouseEventType.move || MouseEventType.hover):
          if (_isDraggingGizmo) {
            final x = event.localPosition.x.toInt();
            final y = event.localPosition.y.toInt();
            await _gizmo!.updateDrag(x, y, context: await GizmoCameraContext.fetch(viewer));
            _reportTransformChange();
          } else if (_gizmo != null) {
            // Fetch camera state once and share it between the position
            // update and hover picking to avoid redundant FFI reads.
            final cameraContext = await GizmoCameraContext.fetch(viewer);
            await _gizmo!.update(cameraPosition: cameraContext.cameraPosition);
            if (!_isDraggingGizmo) {
              final x = event.localPosition.x.toInt();
              final y = event.localPosition.y.toInt();
              await _gizmo!.hover(x, y, context: cameraContext);
            }
          }
          break;

        case ScrollEvent():
          // Update gizmo scale after camera zoom
          await _gizmo?.update();
          break;

        default:
          // Ignore other event types
          break;
      }
    }
  }

  Future<void> _pickAndAttach(int x, int y) async {
    await view.pick(x, y, (result) async {
      if (result.entity == 0) return; // Nothing picked

      _lastPickedEntity = result.entity;

      // Try to find the asset this entity belongs to
      final asset = await _findAssetForEntity(result.entity);
      if (asset == null) {
        // Not part of a known asset, attach directly to entity
        await attachTo(AttachmentTarget.entity(result.entity));
        return;
      }

      // Check if asset has bones
      final boneCount = await asset.getBoneCount(skinIndex: 0);
      if (boneCount == 0) {
        // No bones, attach to entity directly
        await attachTo(AttachmentTarget.entity(result.entity));
        return;
      }

      // Has bones - use strategy to pick one
      if (bonePickStrategy == BonePickStrategy.nearest) {
        await _attachToNearestBone(asset, result, 0);
      }
      // If explicit, do nothing (user must call attachTo with specific bone)
    });
  }

  Future<void> _attachToNearestBone(ThermionAsset asset, PickResult pickResult, int skinIndex) async {
    // Get world position of the pick point
    final camera = await view.getCamera();
    final viewport = await view.getViewport();
    final projMatrix = await camera.getProjectionMatrix();
    final viewMatrix = await camera.getViewMatrix();

    // Unproject to get world position at picked depth
    final ndc = Vector4(
      (pickResult.fragX / viewport.width) * 2 - 1,
      1 - (pickResult.fragY / viewport.height) * 2,
      pickResult.fragZ * 2 - 1,
      1.0,
    );

    final inverseVP = (projMatrix * viewMatrix)..invert();
    final worldPos = inverseVP * ndc;
    _lastPickWorldPosition = (worldPos.xyz / worldPos.w);

    // Find nearest bone
    final boneEntities = await asset.getBones(skinIndex: skinIndex);

    int? nearestBoneIndex;
    double nearestDistance = double.infinity;

    for (int i = 0; i < boneEntities.length; i++) {
      final boneEntity = boneEntities[i];
      if (boneEntity == 0) continue;

      final boneTransform = await viewer.app.transformManager.getWorldTransform(boneEntity);
      final bonePos = boneTransform.getTranslation();

      final distance = bonePos.distanceTo(_lastPickWorldPosition!);
      if (distance < nearestDistance && distance < bonePickThreshold) {
        nearestDistance = distance;
        nearestBoneIndex = i;
      }
    }

    if (nearestBoneIndex != null) {
      final boneEntity = (await asset.getBones(skinIndex: skinIndex))[nearestBoneIndex];
      await attachTo(
        AttachmentTarget(entity: boneEntity, asset: asset, boneIndex: nearestBoneIndex, skinIndex: skinIndex),
      );
    } else {
      // No bone within threshold, attach to entity
      await attachTo(AttachmentTarget.entity(_lastPickedEntity!));
    }
  }

  Future<ThermionAsset?> _findAssetForEntity(ThermionEntity entity) async {
    // This implementation requires tracking which assets have been loaded
    // and their entities. For now, return null (entity-only attachment).
    //
    // TODO: Implement asset lookup by maintaining a registry of loaded assets
    // and their entities. This could be done by:
    // 1. Having the viewer track loaded assets
    // 2. Using containsChild() on each asset
    // 3. Storing a map from entity to asset
    return null;
  }

  void _reportTransformChange() async {
    if (_currentTarget == null || _gizmo == null) return;

    // Use the last computed world transform from the gizmo to avoid
    // floating point drift from reading back via getWorldTransform
    final transform = _gizmo!.lastComputedWorldTransform;
    if (transform != null) {
      onTransformChanged?.call(transform);
    }
  }

  @override
  Future<void> dispose() async {
    await _gizmo?.dispose();
    _gizmo = null;
    _isGizmoInitialized = false;
    _currentTarget = null;
  }
}
