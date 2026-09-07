import 'dart:async';
import '../../../bindings/matrix_buffers.dart' as matrixBuffers;

import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import '../../../bindings/bindings.dart' as bindings;
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of TransformManager for native platforms.
///
/// This class wraps the native Filament TransformManager and provides
/// a type-safe Dart API for managing transform components.
class FFITransformManager extends TransformManager<bindings.Pointer<bindings.TTransformManager>> {
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
  Future createComponent(ThermionEntity entity) async {
    await withVoidCallback(
      (requestId, cb) => bindings.TransformManager_createComponentRenderThread(transformManager, entity, requestId, cb),
    );
  }

  @override
  Future removeComponent(ThermionEntity entity) async {
    await withVoidCallback(
      (requestId, cb) => bindings.TransformManager_removeComponentRenderThread(transformManager, entity, requestId, cb),
    );
  }

  // ============================================================================
  // Transform operations
  // ============================================================================

  @override
  Matrix4 getLocalTransform(ThermionEntity entity) {
    final result = Matrix4.zero();
    getLocalTransformInto(entity, result);
    return result;
  }

  @override
  Matrix4 getWorldTransform(ThermionEntity entity) {
    final result = Matrix4.zero();
    getWorldTransformInto(entity, result);
    return result;
  }

  @override
  void getLocalTransformInto(ThermionEntity entity, Matrix4 out) {
    matrixBuffers.readLocalTransform(transformManager, entity, out.storage);
  }

  @override
  void getWorldTransformInto(ThermionEntity entity, Matrix4 out) {
    matrixBuffers.readWorldTransform(transformManager, entity, out.storage);
  }

  @override
  void setTransform(ThermionEntity entity, Matrix4 transform) {
    matrixBuffers.writeTransform(transformManager, entity, transform.storage);
  }

  @override
  Future setTransformAsync(ThermionEntity entity, Matrix4 transform) async {
    await withVoidCallback((requestId, cb) {
      matrixBuffers.queueTransform(transformManager, entity, transform.storage, requestId, cb);
    });
  }

  @override
  void setTransformNative(ThermionEntity entity, NativeMatrix4 transform) {
    bindings.TransformManager_setTransformNative(transformManager, entity, transform.getNativeHandle());
  }

  @override
  Future<void> setTransformNativeAsync(ThermionEntity entity, NativeMatrix4 transform) {
    // Validate before registering a callback, so disposed inputs cannot leak it.
    final handle = transform.getNativeHandle();
    return withVoidCallback((id, cb) {
      bindings.TransformManager_setTransformNativeRenderThread(transformManager, entity, handle, id, cb);
    });
  }

  @override
  void getLocalTransformNativeInto(ThermionEntity entity, NativeMatrix4 out) {
    bindings.TransformManager_getLocalTransformNativeInto(transformManager, entity, out.getNativeHandle());
  }

  @override
  void getWorldTransformNativeInto(ThermionEntity entity, NativeMatrix4 out) {
    bindings.TransformManager_getWorldTransformNativeInto(transformManager, entity, out.getNativeHandle());
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

    return bindings.TransformManager_transformToUnitCube(transformManager, entity, cAabb);
  }

  // ============================================================================
  // Hierarchy management
  // ============================================================================

  @override
  Future setParent(ThermionEntity child, ThermionEntity? parent, {bool preserveScaling = false}) async {
    final parentId = parent ?? 0; // 0 = null parent in Filament
    await withVoidCallback(
      (requestId, cb) => bindings.TransformManager_setParentRenderThread(
        transformManager,
        child,
        parentId,
        preserveScaling,
        requestId,
        cb,
      ),
    );
  }

  @override
  ThermionEntity? getParent(ThermionEntity child) {
    final parentId = bindings.TransformManager_getParent(transformManager, child);
    // Return null if parent is 0 (no parent)
    return parentId == 0 ? null : parentId;
  }

  @override
  ThermionEntity? getAncestor(ThermionEntity entity) {
    final ancestorId = bindings.TransformManager_getAncestor(transformManager, entity);
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
