#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

    // Component lifecycle
    EMSCRIPTEN_KEEPALIVE void RenderableManager_destroyEntity(TRenderableManager *tRenderableManager, EntityId entityId);

    // Component queries
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_hasComponent(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_empty(TRenderableManager *tRenderableManager);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_isRenderable(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE size_t RenderableManager_getComponentCount(TRenderableManager *tRenderableManager);

    // Material instance management
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_setMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex, TMaterialInstance *tMaterialInstance);
    EMSCRIPTEN_KEEPALIVE TMaterialInstance *RenderableManager_getMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_clearMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex);

    // Non-indexed runtime geometry swap (attribute-less/procedural rendering):
    // no IndexBuffer, [offset, count) select a vertex range of an
    // attribute-less VertexBuffer (bufferCount(0), no declared attributes).
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_setGeometryAtNonIndexed(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex, uint8_t type, TVertexBuffer *vertices, size_t offset, size_t count);

    // Primitive management
    EMSCRIPTEN_KEEPALIVE size_t RenderableManager_getPrimitiveCount(TRenderableManager *tRenderableManager, EntityId entityId);

    // Bounding box management
    EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getAxisAlignedBoundingBox(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setAxisAlignedBoundingBox(TRenderableManager *tRenderableManager, EntityId entityId, Aabb3 aabb);
    EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getAabb(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getBoundingBox(TRenderableManager *tRenderableManager, EntityId entityId);

    // Layer mask and visibility
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setLayerMask(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t select, uint8_t values);
    EMSCRIPTEN_KEEPALIVE uint8_t RenderableManager_getLayerMask(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setVisibilityLayer(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t layer);

    // Priority and channel
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setPriority(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t priority);
    EMSCRIPTEN_KEEPALIVE uint8_t RenderableManager_getPriority(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setChannel(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t channel);

    // Culling
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setCulling(TRenderableManager *tRenderableManager, EntityId entityId, bool enabled);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_getCulling(TRenderableManager *tRenderableManager, EntityId entityId);

    // Fog
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setFogEnabled(TRenderableManager *tRenderableManager, EntityId entityId, bool enabled);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_getFogEnabled(TRenderableManager *tRenderableManager, EntityId entityId);

    // Light channels
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setLightChannel(TRenderableManager *tRenderableManager, EntityId entityId, unsigned int channel, bool enable);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_getLightChannel(TRenderableManager *tRenderableManager, EntityId entityId, unsigned int channel);

    // Shadow options
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setCastShadows(TRenderableManager *tRenderableManager, EntityId entityId, bool castShadows);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_isShadowCaster(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setReceiveShadows(TRenderableManager *tRenderableManager, EntityId entityId, bool receiveShadows);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_isShadowReceiver(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setScreenSpaceContactShadows(TRenderableManager *tRenderableManager, EntityId entityId, bool enabled);

    // Blend order
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setBlendOrderAt(TRenderableManager *tRenderableManager, EntityId entityId, size_t primitiveIndex, uint16_t order);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setGlobalBlendOrderEnabledAt(TRenderableManager *tRenderableManager, EntityId entityId, size_t primitiveIndex, bool enabled);

    // Morph targets
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setMorphWeights(TRenderableManager *tRenderableManager, EntityId entityId, const float *weights, size_t count, size_t offset);
    EMSCRIPTEN_KEEPALIVE size_t RenderableManager_getMorphTargetCount(TRenderableManager *tRenderableManager, EntityId entityId);

    // Skinning / bone transforms
    // transforms is an array of boneCount 4x4 matrices in column-major order (16 floats per matrix).
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromMat4(TRenderableManager *tRenderableManager, EntityId entityId, const float *transforms, size_t boneCount, size_t offset);
    // bones is an array of boneCount Bone structs (8 floats per bone: quat4 + translation3 + reserved1).
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromBone(TRenderableManager *tRenderableManager, EntityId entityId, const float *bones, size_t boneCount, size_t offset);

    // ============================================================================
    // RenderableBuilder
    // ============================================================================

    // Builder lifecycle
    EMSCRIPTEN_KEEPALIVE TRenderableBuilder* RenderableBuilder_create(size_t primitiveCount);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_destroy(TRenderableBuilder *builder);

    // Builder configuration methods
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_boundingBox(TRenderableBuilder *builder, Aabb3 aabb);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_material(TRenderableBuilder *builder, size_t primitiveIndex, TMaterialInstance *materialInstance);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_geometry(TRenderableBuilder *builder, size_t primitiveIndex, uint8_t type, TVertexBuffer *vertices, TIndexBuffer *indices, size_t offset, size_t count);
    // Non-indexed geometry (attribute-less/procedural rendering): no
    // IndexBuffer; the VertexBuffer must have bufferCount(0) and no declared
    // attributes, and positions come from getVertexIndex() in the material.
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_geometryNonIndexed(TRenderableBuilder *builder, size_t primitiveIndex, uint8_t type, TVertexBuffer *vertices, size_t offset, size_t count);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_priority(TRenderableBuilder *builder, uint8_t priority);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_channel(TRenderableBuilder *builder, uint8_t channel);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_culling(TRenderableBuilder *builder, bool enabled);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_castShadows(TRenderableBuilder *builder, bool enabled);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_receiveShadows(TRenderableBuilder *builder, bool enabled);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_fog(TRenderableBuilder *builder, bool enabled);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_lightChannel(TRenderableBuilder *builder, unsigned int channel, bool enabled);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_layerMask(TRenderableBuilder *builder, uint8_t select, uint8_t values);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_screenSpaceContactShadows(TRenderableBuilder *builder, bool enabled);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_blendOrder(TRenderableBuilder *builder, size_t primitiveIndex, uint16_t order);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_globalBlendOrderEnabled(TRenderableBuilder *builder, size_t primitiveIndex, bool enabled);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_instances(TRenderableBuilder *builder, size_t instanceCount);

    // Skinning
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_skinningFromMat4(TRenderableBuilder *builder, size_t boneCount, const float *transforms);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_skinningFromBone(TRenderableBuilder *builder, size_t boneCount, const float *bones);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_enableSkinningBuffers(TRenderableBuilder *builder, bool enabled);
    EMSCRIPTEN_KEEPALIVE void RenderableBuilder_boneIndicesAndWeights(TRenderableBuilder *builder, size_t primitiveIndex, const float *indicesAndWeights, size_t count, size_t bonesPerVertex);

    // Build the renderable
    EMSCRIPTEN_KEEPALIVE int RenderableBuilder_build(TRenderableBuilder *builder, TEngine *engine, EntityId entity);

#ifdef __cplusplus
}
#endif