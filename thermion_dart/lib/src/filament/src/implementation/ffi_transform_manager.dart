import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/utils/src/matrix.dart';
import '../../../bindings/bindings.dart' as bindings;
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of TransformManager for native platforms.
///
/// This class wraps the native Filament TransformManager and provides
/// a type-safe Dart API for managing transform components.
class FFITransformManager
    extends TransformManager<bindings.Pointer<bindings.TTransformManager>> {

  final bindings.Pointer<bindings.TTransformManager> transformManager;
  final FFIFilamentApp app;

  FFITransformManager(this.transformManager, this.app);

  @override
  bindings.Pointer<bindings.TTransformManager> getNativeHandle() => transformManager;

  // ============================================================================
  // Component queries
  // ============================================================================

  @override
  bool hasComponent(ThermionEntity entity) {
    return bindings.TransformManager_hasComponent(transformManager, entity);
  }

  @override
  bool empty() {
    return bindings.TransformManager_empty(transformManager);
  }

  @override
  int getComponentCount() {
    return bindings.TransformManager_getComponentCount(transformManager);
  }

  // ============================================================================
  // Component lifecycle
  // ============================================================================

  @override
  void createComponent(ThermionEntity entity) {
    bindings.TransformManager_createComponent(transformManager, entity);
  }

  @override
  void removeComponent(ThermionEntity entity) async {
    await withVoidCallback((requestId, cb) => bindings.TransformManager_removeComponentRenderThread(transformManager, entity, requestId, cb));
  }

  // ============================================================================
  // Transform operations
  // ============================================================================

  @override
  Matrix4 getLocalTransform(ThermionEntity entity) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    final transform = double4x4ToMatrix4(
        bindings.TransformManager_getLocalTransform(transformManager, entity));

    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
    }
    return transform;
  }

  @override
  Matrix4 getWorldTransform(ThermionEntity entity) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    var transform = double4x4ToMatrix4(
        TransformManager_getWorldTransform(transformManager, entity));
    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
    }

    return transform;
  }

  @override
  void setTransform(ThermionEntity entity, Matrix4 transform) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    bindings.TransformManager_setTransform(
        transformManager, entity, matrix4ToDouble4x4(transform));
    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
    }
  }

  @override
  bool transformToUnitCube(ThermionEntity entity, Aabb3 boundingBox) {
    // Convert Aabb3 to C struct format
    final cAabb = bindings.StructAllocator.create<bindings.Aabb3>();

    final center = Vector3.zero();
    final halfExtents = Vector3.zero();
    boundingBox.copyCenterAndHalfExtents(center, halfExtents);

    cAabb.centerX = center.x;
    cAabb.centerY = center.y;
    cAabb.centerZ = center.z;
    cAabb.halfExtentX = halfExtents.x;
    cAabb.halfExtentY = halfExtents.y;
    cAabb.halfExtentZ = halfExtents.z;

    return bindings.TransformManager_transformToUnitCube(
        transformManager, entity, cAabb);
  }

  // ============================================================================
  // Hierarchy management
  // ============================================================================

  @override
  void setParent(ThermionEntity child, ThermionEntity? parent,
      {bool preserveScaling = false}) {
    if (parent == null) {
      // Use 0 as null parent entity ID
      bindings.TransformManager_setParent(
          transformManager, child, 0, preserveScaling);
    } else {
      bindings.TransformManager_setParent(
          transformManager, child, parent, preserveScaling);
    }
  }

  @override
  ThermionEntity? getParent(ThermionEntity child) {
    final parentId =
        bindings.TransformManager_getParent(transformManager, child);
    // Return null if parent is 0 (no parent)
    return parentId == 0 ? null : parentId;
  }

  @override
  ThermionEntity? getAncestor(ThermionEntity entity) {
    final ancestorId =
        bindings.TransformManager_getAncestor(transformManager, entity);
    // Return null if ancestor is 0 (no ancestor)
    return ancestorId == 0 ? null : ancestorId;
  }

  // ============================================================================
  // Transform transactions
  // ============================================================================

  @override
  void openLocalTransformTransaction() {
    bindings.TransformManager_openLocalTransformTransaction(transformManager);
  }

  @override
  void commitLocalTransformTransaction() {
    bindings.TransformManager_commitLocalTransformTransaction(transformManager);
  }

  // ============================================================================
  // Children management
  // ============================================================================

  @override
  int getChildCount(ThermionEntity parent) {
    return bindings.TransformManager_getChildCount(transformManager, parent);
  }

  @override
  List<ThermionEntity> getChildren(ThermionEntity parent) {
    final count = getChildCount(parent);
    if (count <= 0) {
      return [];
    }

    final children = makeInt32List(count);
    if (count > 0) {
      bindings.TransformManager_getChildren(transformManager, parent, children.address, count);
    }

    return Int32List.fromList(children).cast<ThermionEntity>();
  }
}
