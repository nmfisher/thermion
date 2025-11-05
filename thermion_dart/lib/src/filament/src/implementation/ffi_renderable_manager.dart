import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import '../../../bindings/bindings.dart' as bindings;
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/interface/renderable_manager.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of RenderableManager for native platforms.
///
/// This class wraps the native Filament RenderableManager and provides
/// a type-safe Dart API for managing renderable components.
class FFIRenderableManager
    extends RenderableManager<Pointer<TRenderableManager>> {
  late final _logger = Logger(runtimeType.toString());

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
  Future<bool> setMaterialInstanceAt(ThermionEntity entity, int primitiveIndex,
      MaterialInstance materialInstance) async {
    return RenderableManager_setMaterialInstanceAt(renderableManager, entity,
        primitiveIndex, (materialInstance as FFIMaterialInstance).pointer);
  }

  @override
  Future<MaterialInstance?> getMaterialInstanceAt(
      ThermionEntity entity, int primitiveIndex) async {
    final instancePtr = RenderableManager_getMaterialInstanceAt(
        renderableManager, entity, primitiveIndex);

    if (instancePtr == nullptr) {
      return null;
    }

    return FFIMaterialInstance(instancePtr, app);
  }

  @override
  Future clearMaterialInstanceAt(
      ThermionEntity entity, int primitiveIndex) async {
    RenderableManager_clearMaterialInstanceAt(
        renderableManager, entity, primitiveIndex);
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
    final bb =
        RenderableManager_getAxisAlignedBoundingBox(renderableManager, entity);
    return Aabb3.centerAndHalfExtents(
        Vector3(bb.centerX, bb.centerY, bb.centerZ),
        Vector3(bb.halfExtentX, bb.halfExtentY, bb.halfExtentZ));
  }

  @override
  Future setAxisAlignedBoundingBox(ThermionEntity entity, Aabb3 aabb) async {
    // Convert Aabb3 to the C struct format
    final cAabb = Struct.create<bindings.Aabb3>();
    cAabb.centerX = aabb.center.x;
    cAabb.centerY = aabb.center.y;
    cAabb.centerZ = aabb.center.z;
    cAabb.halfExtentX = (aabb.max.x - aabb.min.x) / 2;
    cAabb.halfExtentY = (aabb.max.y - aabb.min.y) / 2;
    cAabb.halfExtentZ = (aabb.max.z - aabb.min.z) / 2;

    RenderableManager_setAxisAlignedBoundingBox(
        renderableManager, entity, cAabb);
  }

  @override
  Aabb3 getBoundingBox(ThermionEntity entity) {
    final bb = RenderableManager_getBoundingBox(renderableManager, entity);
    return Aabb3.centerAndHalfExtents(
        Vector3(bb.centerX, bb.centerY, bb.centerZ),
        Vector3(bb.halfExtentX, bb.halfExtentY, bb.halfExtentZ));
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
  Future setLightChannel(
      ThermionEntity entity, int channel, bool enable) async {
    RenderableManager_setLightChannel(
        renderableManager, entity, channel, enable);
  }

  @override
  bool getLightChannel(ThermionEntity entity, int channel) {
    return RenderableManager_getLightChannel(
        renderableManager, entity, channel);
  }

  // ============================================================================
  // Shadow options
  // ============================================================================

  @override
  Future setCastShadows(ThermionEntity entity, bool enabled) async {
    RenderableManager_setCastShadows(renderableManager, entity, enabled);
  }

  @override
  bool isShadowCaster(ThermionEntity entity) {
    return RenderableManager_isShadowCaster(renderableManager, entity);
  }

  @override
  Future setReceiveShadows(ThermionEntity entity, bool enabled) async {
    RenderableManager_setReceiveShadows(renderableManager, entity, enabled);
  }

  @override
  bool isShadowReceiver(ThermionEntity entity) {
    return RenderableManager_isShadowReceiver(renderableManager, entity);
  }

  @override
  Future setScreenSpaceContactShadows(
      ThermionEntity entity, bool enabled) async {
    RenderableManager_setScreenSpaceContactShadows(
        renderableManager, entity, enabled);
  }

  // ============================================================================
  // Blend order
  // ============================================================================

  @override
  Future setBlendOrderAt(
      ThermionEntity entity, int primitiveIndex, int order) async {
    RenderableManager_setBlendOrderAt(
        renderableManager, entity, primitiveIndex, order);
  }

  @override
  Future setGlobalBlendOrderEnabledAt(
      ThermionEntity entity, int primitiveIndex, bool enabled) async {
    RenderableManager_setGlobalBlendOrderEnabledAt(
        renderableManager, entity, primitiveIndex, enabled);
  }

  // ============================================================================
  // Morph targets
  // ============================================================================

  @override
  Future setMorphWeights(ThermionEntity entity, List<double> weights, int count,
      {int offset = 0}) async {
    final weightsPtr = makeFloat32List(weights.length);
    for (int i = 0; i < weights.length; i++) {
      weightsPtr[i] = weights[i];
    }

    RenderableManager_setMorphWeights(
        renderableManager, entity, weightsPtr.address, count, offset);

    if (FILAMENT_WASM) {
      weightsPtr.free();
    }
  }

  @override
  int getMorphTargetCount(ThermionEntity entity) {
    return RenderableManager_getMorphTargetCount(renderableManager, entity);
  }
}
