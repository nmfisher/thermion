import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import '../../../bindings/bindings.dart' as bindings;
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of RenderableManager for native platforms.
///
/// This class wraps the native Filament RenderableManager and provides
/// a type-safe Dart API for managing renderable components.
class FFIRenderableManager extends RenderableManager<Pointer<TRenderableManager>> {
  final Pointer<TRenderableManager> renderableManager;
  final FFIFilamentApp app;

  FFIRenderableManager(this.renderableManager, this.app);

  @override
  Pointer<TRenderableManager> getNativeHandle() => renderableManager;

  // ============================================================================
  // Component queries
  // ============================================================================

  @override
  bool hasComponent(ThermionEntity entity) {
    return RenderableManager_hasComponent(renderableManager, entity);
  }

  @override
  bool empty() {
    return RenderableManager_empty(renderableManager);
  }

  @override
  bool isRenderable(ThermionEntity entity) {
    return RenderableManager_isRenderable(renderableManager, entity);
  }

  @override
  int getComponentCount() {
    return RenderableManager_getComponentCount(renderableManager);
  }

  // ============================================================================
  // Material instance management
  // ============================================================================

  @override
  Future<bool> setMaterialInstanceAt(
    ThermionEntity entity,
    int primitiveIndex,
    MaterialInstance materialInstance,
  ) async {
    return RenderableManager_setMaterialInstanceAt(
      renderableManager,
      entity,
      primitiveIndex,
      (materialInstance as FFIMaterialInstance).pointer,
    );
  }

  @override
  Future<bool> setGeometryAtNonIndexed(
    ThermionEntity entity,
    int primitiveIndex,
    PrimitiveType type,
    VertexBuffer vertices,
    int offset,
    int count,
  ) async {
    final typeValue = _primitiveTypeToValue(type);
    return RenderableManager_setGeometryAtNonIndexed(
      renderableManager,
      entity,
      primitiveIndex,
      typeValue,
      (vertices as FFIVertexBuffer).getNativeHandle(),
      offset,
      count,
    );
  }

  @override
  Future<MaterialInstance?> getMaterialInstanceAt(ThermionEntity entity, int primitiveIndex) async {
    final instancePtr = RenderableManager_getMaterialInstanceAt(renderableManager, entity, primitiveIndex);

    if (instancePtr == nullptr) {
      return null;
    }

    return FFIMaterialInstance(instancePtr, app);
  }

  @override
  Future clearMaterialInstanceAt(ThermionEntity entity, int primitiveIndex) async {
    RenderableManager_clearMaterialInstanceAt(renderableManager, entity, primitiveIndex);
  }

  // ============================================================================
  // Primitive management
  // ============================================================================

  @override
  int getPrimitiveCount(ThermionEntity entity) {
    return RenderableManager_getPrimitiveCount(renderableManager, entity);
  }

  // ============================================================================
  // Bounding box management
  // ============================================================================

  @override
  Aabb3 getAxisAlignedBoundingBox(ThermionEntity entity) {
    final bb = RenderableManager_getAxisAlignedBoundingBox(renderableManager, entity);
    return Aabb3.centerAndHalfExtents(
      Vector3(bb.centerX, bb.centerY, bb.centerZ),
      Vector3(bb.halfExtentX, bb.halfExtentY, bb.halfExtentZ),
    );
  }

  @override
  Future setAxisAlignedBoundingBox(ThermionEntity entity, Aabb3 aabb) async {
    // Convert Aabb3 to the C struct format
    final cAabb = StructAllocator.create<bindings.Aabb3>();
    cAabb.centerX = aabb.center.x;
    cAabb.centerY = aabb.center.y;
    cAabb.centerZ = aabb.center.z;
    cAabb.halfExtentX = (aabb.max.x - aabb.min.x) / 2;
    cAabb.halfExtentY = (aabb.max.y - aabb.min.y) / 2;
    cAabb.halfExtentZ = (aabb.max.z - aabb.min.z) / 2;

    RenderableManager_setAxisAlignedBoundingBox(renderableManager, entity, cAabb);
  }

  @override
  Aabb3 getBoundingBox(ThermionEntity entity) {
    final bb = RenderableManager_getBoundingBox(renderableManager, entity);
    return Aabb3.centerAndHalfExtents(
      Vector3(bb.centerX, bb.centerY, bb.centerZ),
      Vector3(bb.halfExtentX, bb.halfExtentY, bb.halfExtentZ),
    );
  }

  // ============================================================================
  // Layer mask and visibility
  // ============================================================================

  @override
  Future setLayerMask(ThermionEntity entity, int select, int values) async {
    RenderableManager_setLayerMask(renderableManager, entity, select, values);
  }

  @override
  int getLayerMask(ThermionEntity entity) {
    return RenderableManager_getLayerMask(renderableManager, entity);
  }

  @override
  Future setVisibilityLayer(ThermionEntity entity, int layer) async {
    RenderableManager_setVisibilityLayer(renderableManager, entity, layer);
  }

  // ============================================================================
  // Priority and channel
  // ============================================================================

  @override
  Future setPriority(ThermionEntity entity, int priority) async {
    RenderableManager_setPriority(renderableManager, entity, priority);
  }

  @override
  Future setChannel(ThermionEntity entity, int channel) async {
    RenderableManager_setChannel(renderableManager, entity, channel);
  }

  // ============================================================================
  // Culling and fog
  // ============================================================================

  @override
  Future setCulling(ThermionEntity entity, bool enabled) async {
    RenderableManager_setCulling(renderableManager, entity, enabled);
  }

  @override
  Future setFogEnabled(ThermionEntity entity, bool enabled) async {
    RenderableManager_setFogEnabled(renderableManager, entity, enabled);
  }

  @override
  bool getFogEnabled(ThermionEntity entity) {
    return RenderableManager_getFogEnabled(renderableManager, entity);
  }

  // ============================================================================
  // Light channels
  // ============================================================================

  @override
  Future setLightChannel(ThermionEntity entity, int channel, bool enable) async {
    RenderableManager_setLightChannel(renderableManager, entity, channel, enable);
  }

  @override
  bool getLightChannel(ThermionEntity entity, int channel) {
    return RenderableManager_getLightChannel(renderableManager, entity, channel);
  }

  // ============================================================================
  // Shadow options
  // ============================================================================

  @override
  Future setCastShadows(ThermionEntity entity, bool enabled) async {
    await withVoidCallback(
      (requestId, cb) =>
          RenderableManager_setCastShadowsRenderThread(renderableManager, entity, enabled, requestId, cb),
    );
  }

  @override
  bool isShadowCaster(ThermionEntity entity) {
    return RenderableManager_isShadowCaster(renderableManager, entity);
  }

  @override
  Future setReceiveShadows(ThermionEntity entity, bool enabled) async {
    await withVoidCallback(
      (requestId, cb) =>
          RenderableManager_setReceiveShadowsRenderThread(renderableManager, entity, enabled, requestId, cb),
    );
  }

  @override
  bool isShadowReceiver(ThermionEntity entity) {
    return RenderableManager_isShadowReceiver(renderableManager, entity);
  }

  @override
  Future setScreenSpaceContactShadows(ThermionEntity entity, bool enabled) async {
    RenderableManager_setScreenSpaceContactShadows(renderableManager, entity, enabled);
  }

  // ============================================================================
  // Blend order
  // ============================================================================

  @override
  Future setBlendOrderAt(ThermionEntity entity, int primitiveIndex, int order) async {
    RenderableManager_setBlendOrderAt(renderableManager, entity, primitiveIndex, order);
  }

  @override
  Future setGlobalBlendOrderEnabledAt(ThermionEntity entity, int primitiveIndex, bool enabled) async {
    RenderableManager_setGlobalBlendOrderEnabledAt(renderableManager, entity, primitiveIndex, enabled);
  }

  // ============================================================================
  // Morph targets
  // ============================================================================

  @override
  Future setMorphWeights(ThermionEntity entity, List<double> weights, int count, {int offset = 0}) async {
    final weightsPtr = makeFloat32List(weights.length);
    for (int i = 0; i < weights.length; i++) {
      weightsPtr[i] = weights[i];
    }

    RenderableManager_setMorphWeights(renderableManager, entity, weightsPtr.address, count, offset);

    if (FILAMENT_WASM) {
      weightsPtr.free();
    }
  }

  @override
  int getMorphTargetCount(ThermionEntity entity) {
    return RenderableManager_getMorphTargetCount(renderableManager, entity);
  }

  // ============================================================================
  // Skinning
  // ============================================================================

  @override
  Future setBonesFromMat4(ThermionEntity entity, List<Matrix4> transforms, {int offset = 0}) async {
    final boneCount = transforms.length;
    if (boneCount == 0) {
      return;
    }

    final transformsPtr = makeFloat32List(boneCount * 16);
    for (int i = 0; i < boneCount; i++) {
      final storage = transforms[i].storage;
      for (int j = 0; j < 16; j++) {
        transformsPtr[i * 16 + j] = storage[j];
      }
    }

    await withVoidCallback(
      (requestId, cb) => RenderableManager_setBonesFromMat4RenderThread(
        renderableManager,
        entity,
        transformsPtr.address,
        boneCount,
        offset,
        requestId,
        cb,
      ),
    );

    if (FILAMENT_WASM) {
      transformsPtr.free();
    }
  }

  @override
  Future setBonesFromBone(ThermionEntity entity, List<BoneData> bones, {int offset = 0}) async {
    if (bones.isEmpty) {
      return;
    }

    final bonesData = BoneData.toFloat32List(bones);
    final bonesPtr = makeFloat32List(bonesData.length);
    for (int i = 0; i < bonesData.length; i++) {
      bonesPtr[i] = bonesData[i];
    }

    await withVoidCallback(
      (requestId, cb) => RenderableManager_setBonesFromBoneRenderThread(
        renderableManager,
        entity,
        bonesPtr.address,
        bones.length,
        offset,
        requestId,
        cb,
      ),
    );

    if (FILAMENT_WASM) {
      bonesPtr.free();
    }
  }

  // ============================================================================
  // Builder
  // ============================================================================

  @override
  RenderableBuilder createBuilder(int primitiveCount) {
    return FFIRenderableBuilder(primitiveCount, app);
  }

  @override
  VertexBufferBuilder createVertexBufferBuilder() {
    return FFIVertexBufferBuilder(app.engine);
  }

  @override
  IndexBufferBuilder createIndexBufferBuilder() {
    return FFIIndexBufferBuilder(app.engine);
  }
}

/// FFI implementation of RenderableBuilder for native platforms.
class FFIRenderableBuilder implements RenderableBuilder {
  bindings.Pointer<TRenderableBuilder>? _builderPtr;
  final FFIFilamentApp _app;
  bool _isBuilt = false;

  FFIRenderableBuilder(int primitiveCount, this._app) {
    _builderPtr = bindings.RenderableBuilder_create(primitiveCount);
  }

  void _checkNotBuilt() {
    if (_isBuilt) {
      throw StateError('Builder has already been built and cannot be reused');
    }
    if (_builderPtr == null || _builderPtr == nullptr) {
      throw StateError('Builder pointer is null');
    }
  }

  @override
  void boundingBox(Aabb3 aabb) {
    _checkNotBuilt();
    final center = Vector3.zero();
    final halfExtents = Vector3.zero();
    aabb.copyCenterAndHalfExtents(center, halfExtents);

    final cAabb = StructAllocator.create<bindings.Aabb3>();
    cAabb.centerX = center.x;
    cAabb.centerY = center.y;
    cAabb.centerZ = center.z;
    cAabb.halfExtentX = halfExtents.x;
    cAabb.halfExtentY = halfExtents.y;
    cAabb.halfExtentZ = halfExtents.z;

    bindings.RenderableBuilder_boundingBox(_builderPtr!, cAabb);
  }

  @override
  void material(int primitiveIndex, MaterialInstance materialInstance) {
    _checkNotBuilt();
    final materialPtr = (materialInstance as FFIMaterialInstance).pointer;
    bindings.RenderableBuilder_material(_builderPtr!, primitiveIndex, materialPtr);
  }

  @override
  void geometry(
    int primitiveIndex,
    PrimitiveType type,
    VertexBuffer vertices,
    IndexBuffer indices,
    int offset,
    int count,
  ) {
    _checkNotBuilt();

    // Extract native handles from the buffer objects
    final verticesPtr = (vertices as FFIVertexBuffer).getNativeHandle();
    final indicesPtr = (indices as FFIIndexBuffer).getNativeHandle();

    final typeValue = _primitiveTypeToValue(type);

    bindings.RenderableBuilder_geometry(
      _builderPtr!,
      primitiveIndex,
      typeValue,
      verticesPtr,
      indicesPtr,
      offset,
      count,
    );
  }

  @override
  void geometryNonIndexed(int primitiveIndex, PrimitiveType type, VertexBuffer vertices, int offset, int count) {
    _checkNotBuilt();

    // Extract native handle from the buffer object
    final verticesPtr = (vertices as FFIVertexBuffer).getNativeHandle();

    final typeValue = _primitiveTypeToValue(type);

    bindings.RenderableBuilder_geometryNonIndexed(_builderPtr!, primitiveIndex, typeValue, verticesPtr, offset, count);
  }

  @override
  void priority(int priority) {
    _checkNotBuilt();
    bindings.RenderableBuilder_priority(_builderPtr!, priority);
  }

  @override
  void channel(int channel) {
    _checkNotBuilt();
    bindings.RenderableBuilder_channel(_builderPtr!, channel);
  }

  @override
  void culling(bool enabled) {
    _checkNotBuilt();
    bindings.RenderableBuilder_culling(_builderPtr!, enabled);
  }

  @override
  void castShadows(bool enabled) {
    _checkNotBuilt();
    bindings.RenderableBuilder_castShadows(_builderPtr!, enabled);
  }

  @override
  void receiveShadows(bool enabled) {
    _checkNotBuilt();
    bindings.RenderableBuilder_receiveShadows(_builderPtr!, enabled);
  }

  @override
  void fog(bool enabled) {
    _checkNotBuilt();
    bindings.RenderableBuilder_fog(_builderPtr!, enabled);
  }

  @override
  void lightChannel(int channel, bool enabled) {
    _checkNotBuilt();
    bindings.RenderableBuilder_lightChannel(_builderPtr!, channel, enabled);
  }

  @override
  void layerMask(int select, int values) {
    _checkNotBuilt();
    bindings.RenderableBuilder_layerMask(_builderPtr!, select, values);
  }

  @override
  void screenSpaceContactShadows(bool enabled) {
    _checkNotBuilt();
    bindings.RenderableBuilder_screenSpaceContactShadows(_builderPtr!, enabled);
  }

  @override
  void blendOrder(int primitiveIndex, int order) {
    _checkNotBuilt();
    bindings.RenderableBuilder_blendOrder(_builderPtr!, primitiveIndex, order);
  }

  @override
  void globalBlendOrderEnabled(int primitiveIndex, bool enabled) {
    _checkNotBuilt();
    bindings.RenderableBuilder_globalBlendOrderEnabled(_builderPtr!, primitiveIndex, enabled);
  }

  @override
  void instances(int instanceCount) {
    _checkNotBuilt();
    bindings.RenderableBuilder_instances(_builderPtr!, instanceCount);
  }

  // ============================================================================
  // Skinning
  // ============================================================================

  @override
  void skinning(int boneCount, List<Matrix4> transforms) {
    _checkNotBuilt();
    final transformsData = BoneData.matricesToFloat32List(transforms);
    final transformsPtr = makeFloat32List(transformsData.length);
    for (int i = 0; i < transformsData.length; i++) {
      transformsPtr[i] = transformsData[i];
    }

    bindings.RenderableBuilder_skinningFromMat4(_builderPtr!, boneCount, transformsPtr.address);

    if (FILAMENT_WASM) {
      transformsPtr.free();
    }
  }

  @override
  void skinningFromBone(int boneCount, List<BoneData> bones) {
    _checkNotBuilt();
    final bonesData = BoneData.toFloat32List(bones);
    final bonesPtr = makeFloat32List(bonesData.length);
    for (int i = 0; i < bonesData.length; i++) {
      bonesPtr[i] = bonesData[i];
    }

    bindings.RenderableBuilder_skinningFromBone(_builderPtr!, boneCount, bonesPtr.address);

    if (FILAMENT_WASM) {
      bonesPtr.free();
    }
  }

  @override
  void enableSkinningBuffers(bool enabled) {
    _checkNotBuilt();
    bindings.RenderableBuilder_enableSkinningBuffers(_builderPtr!, enabled);
  }

  @override
  void boneIndicesAndWeights(int primitiveIndex, List<Float32List> indicesAndWeights, int bonesPerVertex) {
    _checkNotBuilt();

    final totalPairs = indicesAndWeights.length;
    final dataPtr = makeFloat32List(totalPairs * 2);

    int offset = 0;
    for (final pair in indicesAndWeights) {
      dataPtr[offset++] = pair[0]; // bone index
      dataPtr[offset++] = pair[1]; // weight
    }

    bindings.RenderableBuilder_boneIndicesAndWeights(
      _builderPtr!,
      primitiveIndex,
      dataPtr.address,
      totalPairs,
      bonesPerVertex,
    );

    if (FILAMENT_WASM) {
      dataPtr.free();
    }
  }

  @override
  Future<bool> build(ThermionEntity entity) async {
    _checkNotBuilt();

    final result = await withIntCallback(
      (cb) => bindings.RenderableBuilder_buildRenderThread(_builderPtr!, _app.engine, entity, cb.cast()),
    );

    // Clean up the builder
    bindings.RenderableBuilder_destroy(_builderPtr!);
    _builderPtr = null;
    _isBuilt = true;

    // Result: 0 = Success, -1 = Error
    return result == 0;
  }
}

/// Maps a PrimitiveType to the filament::RenderableManager::PrimitiveType
/// ordinal expected by the C API.
int _primitiveTypeToValue(PrimitiveType type) => switch (type) {
  PrimitiveType.POINTS => 0,
  PrimitiveType.LINES => 1,
  PrimitiveType.UNUSED1 => 2,
  PrimitiveType.LINE_STRIP => 3,
  PrimitiveType.TRIANGLES => 4,
  PrimitiveType.TRIANGLE_STRIP => 5,
};
