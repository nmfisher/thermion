#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <math/mat4.h>
#include <utils/Entity.h>

#include "Log.hpp"
#include "c_api/TRenderableManager.h"

namespace thermion
{
    extern "C"
    {
        using namespace filament;
        using namespace utils;

        EMSCRIPTEN_KEEPALIVE size_t RenderableManager_getPrimitiveCount(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if(!renderableInstance.isValid()) {
                return 0;
            }
            return renderableManager->getPrimitiveCount(renderableInstance);
        }

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_setMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex, TMaterialInstance *tMaterialInstance)
        {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if(!renderableInstance.isValid()) {
                return false;
            }
            auto materialInstance = reinterpret_cast<MaterialInstance *>(tMaterialInstance);
            renderableManager->setMaterialInstanceAt(renderableInstance, primitiveIndex, materialInstance);
            return true;
        }

        EMSCRIPTEN_KEEPALIVE TMaterialInstance *RenderableManager_getMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if(!renderableInstance.isValid()) {
                return nullptr;
            }
            auto materialInstance = renderableManager->getMaterialInstanceAt(renderableInstance, primitiveIndex);
            return reinterpret_cast<TMaterialInstance*>(materialInstance);
        }

        // Non-indexed runtime geometry swap (Filament's attribute-less/
        // procedural rendering path): no IndexBuffer, [offset, count) select a
        // vertex range of an attribute-less VertexBuffer.
        EMSCRIPTEN_KEEPALIVE bool RenderableManager_setGeometryAtNonIndexed(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex, uint8_t type, TVertexBuffer *tVertices, size_t offset, size_t count) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if(!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return false;
            }
            auto *vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tVertices);
            auto primitiveType = static_cast<filament::RenderableManager::PrimitiveType>(type);
            renderableManager->setGeometryAt(renderableInstance, primitiveIndex, primitiveType, vertexBuffer, offset, count);
            return true;
        }

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_isRenderable(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            return renderableInstance.isValid();
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_destroyEntity(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            renderableManager->destroy(entity);
        }

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_hasComponent(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            return renderableManager->hasComponent(entity);
        }

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_empty(TRenderableManager *tRenderableManager) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            return renderableManager->empty();
        }

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_getLightChannel(TRenderableManager *tRenderableManager, EntityId entityId, unsigned int channel) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                return false;
            }
            return renderableManager->getLightChannel(renderableInstance, channel);
        }

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_isShadowCaster(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return false;
            }
            return renderableManager->isShadowCaster(renderableInstance);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setCastShadows(TRenderableManager *tRenderableManager, EntityId entityId, bool enabled) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            return renderableManager->setCastShadows(renderableInstance, enabled);
        }

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_isShadowReceiver(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return false;
            }
            return renderableManager->isShadowReceiver(renderableInstance);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setReceiveShadows(TRenderableManager *tRenderableManager, EntityId entityId, bool enabled) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            return renderableManager->setReceiveShadows(renderableInstance, enabled);
        }

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_getFogEnabled(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                TRACE("Cannot check fog for entity %d, entity has no renderable instance.", entityId);
                return false;
            }
            return renderableManager->getFogEnabled(renderableInstance);
        }

        EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getAabb(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                TRACE("Cannot return renderable bounding box for entity %d, entity has no renderable instance.", entityId);
                return Aabb3 { };
            }
            auto box = renderableManager->getAxisAlignedBoundingBox(renderableInstance);
            return Aabb3{box.center.x, box.center.y, box.center.z, box.halfExtent.x, box.halfExtent.y, box.halfExtent.z};            
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setVisibilityLayer(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t layer) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            if (!renderableManager->hasComponent(entity)) {
                Log("Entity %d has no renderable component, cannot set visibility layer");
                return;
            }
            auto renderableInstance = renderableManager->getInstance(entity);
            renderableManager->setLayerMask(renderableInstance, 0xFF, 1u << (uint8_t)layer);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setPriority(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t priority) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            
            if (!renderableManager->hasComponent(entity)) {
                Log("Entity %d has no renderable component, cannot set renderable priority");
                return;
            }
            auto renderableInstance = renderableManager->getInstance(entity);
            renderableManager->setPriority(renderableInstance, priority);
        }

        EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getBoundingBox(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);

            if (!renderableManager->hasComponent(entity)) {
                Log("Entity %d has no renderable component, cannot get bounding box");
                return Aabb3{ 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
            }
            auto renderableInstance = renderableManager->getInstance(entity);
            auto boundingBox = renderableManager->getAxisAlignedBoundingBox(renderableInstance);

            return Aabb3{boundingBox.center.x, boundingBox.center.y, boundingBox.center.z, boundingBox.halfExtent.x, boundingBox.halfExtent.y, boundingBox.halfExtent.z};
        }

        // Component queries
        EMSCRIPTEN_KEEPALIVE size_t RenderableManager_getComponentCount(TRenderableManager *tRenderableManager) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            return renderableManager->getComponentCount();
        }

        // Material instance management
        EMSCRIPTEN_KEEPALIVE void RenderableManager_clearMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if(!renderableInstance.isValid()) {
                return;
            }
            renderableManager->clearMaterialInstanceAt(renderableInstance, primitiveIndex);
        }

        // Bounding box management
        EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getAxisAlignedBoundingBox(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                return Aabb3{ 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
            }
            auto box = renderableManager->getAxisAlignedBoundingBox(renderableInstance);
            return Aabb3{box.center.x, box.center.y, box.center.z, box.halfExtent.x, box.halfExtent.y, box.halfExtent.z};
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setAxisAlignedBoundingBox(TRenderableManager *tRenderableManager, EntityId entityId, Aabb3 aabb) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            filament::Box box;
            box.center = {aabb.centerX, aabb.centerY, aabb.centerZ};
            box.halfExtent = {aabb.halfExtentX, aabb.halfExtentY, aabb.halfExtentZ};
            renderableManager->setAxisAlignedBoundingBox(renderableInstance, box);
        }

        // Layer mask and visibility
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setLayerMask(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t select, uint8_t values) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setLayerMask(renderableInstance, select, values);
        }

        EMSCRIPTEN_KEEPALIVE uint8_t RenderableManager_getLayerMask(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return 0;
            }
            return renderableManager->getLayerMask(renderableInstance);
        }

        // Priority and channel
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setChannel(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t channel) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setChannel(renderableInstance, channel);
        }

        // Culling
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setCulling(TRenderableManager *tRenderableManager, EntityId entityId, bool enabled) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setCulling(renderableInstance, enabled);
        }

        // Fog
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setFogEnabled(TRenderableManager *tRenderableManager, EntityId entityId, bool enabled) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setFogEnabled(renderableInstance, enabled);
        }

        // Light channels
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setLightChannel(TRenderableManager *tRenderableManager, EntityId entityId, unsigned int channel, bool enable) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setLightChannel(renderableInstance, channel, enable);
        }

        // Shadow options
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setScreenSpaceContactShadows(TRenderableManager *tRenderableManager, EntityId entityId, bool enabled) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setScreenSpaceContactShadows(renderableInstance, enabled);
        }

        // Blend order
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBlendOrderAt(TRenderableManager *tRenderableManager, EntityId entityId, size_t primitiveIndex, uint16_t order) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setBlendOrderAt(renderableInstance, primitiveIndex, order);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setGlobalBlendOrderEnabledAt(TRenderableManager *tRenderableManager, EntityId entityId, size_t primitiveIndex, bool enabled) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setGlobalBlendOrderEnabledAt(renderableInstance, primitiveIndex, enabled);
        }

        // Morph targets
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setMorphWeights(TRenderableManager *tRenderableManager, EntityId entityId, const float *weights, size_t count, size_t offset) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            renderableManager->setMorphWeights(renderableInstance, weights, count, offset);
        }

        EMSCRIPTEN_KEEPALIVE size_t RenderableManager_getMorphTargetCount(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return 0;
            }
            return renderableManager->getMorphTargetCount(renderableInstance);
        }

        // Skinning / bone transforms
        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromMat4(TRenderableManager *tRenderableManager, EntityId entityId, const float *transforms, size_t boneCount, size_t offset) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            auto *mat4Transforms = reinterpret_cast<const filament::math::mat4f *>(transforms);
            renderableManager->setBones(renderableInstance, mat4Transforms, boneCount, offset);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setBonesFromBone(TRenderableManager *tRenderableManager, EntityId entityId, const float *bones, size_t boneCount, size_t offset) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                Log("Error: invalid renderable");
                return;
            }
            // Cast float* to RenderableManager::Bone* (Bone is 8 floats: quat4 + translation3 + reserved1)
            auto *boneTransforms = reinterpret_cast<const filament::RenderableManager::Bone*>(bones);
            renderableManager->setBones(renderableInstance, boneTransforms, boneCount, offset);
        }

        // ============================================================================
        // RenderableBuilder
        // ============================================================================

        EMSCRIPTEN_KEEPALIVE TRenderableBuilder* RenderableBuilder_create(size_t primitiveCount) {
            auto *builder = new filament::RenderableManager::Builder(primitiveCount);
            return reinterpret_cast<TRenderableBuilder*>(builder);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_destroy(TRenderableBuilder *tBuilder) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            delete builder;
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_boundingBox(TRenderableBuilder *tBuilder, Aabb3 aabb) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            filament::Box box;
            box.center = {aabb.centerX, aabb.centerY, aabb.centerZ};
            box.halfExtent = {aabb.halfExtentX, aabb.halfExtentY, aabb.halfExtentZ};
            builder->boundingBox(box);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_material(TRenderableBuilder *tBuilder, size_t primitiveIndex, TMaterialInstance *tMaterialInstance) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            auto *materialInstance = reinterpret_cast<filament::MaterialInstance*>(tMaterialInstance);
            builder->material(primitiveIndex, materialInstance);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_geometry(TRenderableBuilder *tBuilder, size_t primitiveIndex, uint8_t type, TVertexBuffer *tVertices, TIndexBuffer *tIndices, size_t offset, size_t count) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            auto *vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tVertices);
            auto *indexBuffer = reinterpret_cast<filament::IndexBuffer*>(tIndices);
            auto primitiveType = static_cast<filament::RenderableManager::PrimitiveType>(type);
            builder->geometry(primitiveIndex, primitiveType, vertexBuffer, indexBuffer, offset, count);
        }

        // Non-indexed geometry overload (Filament's attribute-less/procedural
        // rendering path): no IndexBuffer is supplied, and [offset, count)
        // select a vertex range. The VertexBuffer must have been built with
        // bufferCount(0) and no declared attributes; positions are computed
        // from getVertexIndex() in the material's vertex block.
        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_geometryNonIndexed(TRenderableBuilder *tBuilder, size_t primitiveIndex, uint8_t type, TVertexBuffer *tVertices, size_t offset, size_t count) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            auto *vertexBuffer = reinterpret_cast<filament::VertexBuffer*>(tVertices);
            auto primitiveType = static_cast<filament::RenderableManager::PrimitiveType>(type);
            builder->geometry(primitiveIndex, primitiveType, vertexBuffer, offset, count);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_priority(TRenderableBuilder *tBuilder, uint8_t priority) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->priority(priority);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_channel(TRenderableBuilder *tBuilder, uint8_t channel) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->channel(channel);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_culling(TRenderableBuilder *tBuilder, bool enabled) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->culling(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_castShadows(TRenderableBuilder *tBuilder, bool enabled) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->castShadows(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_receiveShadows(TRenderableBuilder *tBuilder, bool enabled) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->receiveShadows(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_fog(TRenderableBuilder *tBuilder, bool enabled) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->fog(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_lightChannel(TRenderableBuilder *tBuilder, unsigned int channel, bool enabled) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->lightChannel(channel, enabled);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_layerMask(TRenderableBuilder *tBuilder, uint8_t select, uint8_t values) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->layerMask(select, values);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_screenSpaceContactShadows(TRenderableBuilder *tBuilder, bool enabled) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->screenSpaceContactShadows(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_blendOrder(TRenderableBuilder *tBuilder, size_t primitiveIndex, uint16_t order) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->blendOrder(primitiveIndex, order);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_globalBlendOrderEnabled(TRenderableBuilder *tBuilder, size_t primitiveIndex, bool enabled) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->globalBlendOrderEnabled(primitiveIndex, enabled);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_instances(TRenderableBuilder *tBuilder, size_t instanceCount) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->instances(instanceCount);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_skinningFromMat4(TRenderableBuilder *tBuilder, size_t boneCount, const float *transforms) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            auto *mat4Transforms = reinterpret_cast<const filament::math::mat4f*>(transforms);
            builder->skinning(boneCount, mat4Transforms);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_skinningFromBone(TRenderableBuilder *tBuilder, size_t boneCount, const float *bones) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            auto *boneTransforms = reinterpret_cast<const filament::RenderableManager::Bone*>(bones);
            builder->skinning(boneCount, boneTransforms);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_enableSkinningBuffers(TRenderableBuilder *tBuilder, bool enabled) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            builder->enableSkinningBuffers(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableBuilder_boneIndicesAndWeights(TRenderableBuilder *tBuilder, size_t primitiveIndex, const float *indicesAndWeights, size_t count, size_t bonesPerVertex) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            auto *float2Data = reinterpret_cast<const filament::math::float2*>(indicesAndWeights);
            builder->boneIndicesAndWeights(primitiveIndex, float2Data, count, bonesPerVertex);
        }

        EMSCRIPTEN_KEEPALIVE int RenderableBuilder_build(TRenderableBuilder *tBuilder, TEngine *tEngine, EntityId entityId) {
            auto *builder = reinterpret_cast<filament::RenderableManager::Builder*>(tBuilder);
            auto *engine = reinterpret_cast<filament::Engine*>(tEngine);
            const auto &entity = utils::Entity::import(entityId);

            auto result = builder->build(*engine, entity);
            return static_cast<int>(result);
        }

    }
}