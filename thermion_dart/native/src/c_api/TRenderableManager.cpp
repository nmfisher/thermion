#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
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

        EMSCRIPTEN_KEEPALIVE bool RenderableManager_isRenderable(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            return renderableInstance.isValid();
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
                return false;
            }
            return renderableManager->getFogEnabled(renderableInstance);
        }

        EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getAabb(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            if (!renderableInstance.isValid()) {
                return Aabb3 { };
            }
            auto box = renderableManager->getAxisAlignedBoundingBox(renderableInstance);
            return Aabb3{box.center.x, box.center.y, box.center.z, box.halfExtent.x, box.halfExtent.y, box.halfExtent.z};            
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setVisibilityLayer(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t layer) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            if (!renderableManager->hasComponent(entity)) {
                Log("Not renderable");
                return;
            }
            auto renderableInstance = renderableManager->getInstance(entity);
            renderableManager->setLayerMask(renderableInstance, 0xFF, 1u << (uint8_t)layer);
        }

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setPriority(TRenderableManager *tRenderableManager, EntityId entityId, uint8_t priority) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            
            if (!renderableManager->hasComponent(entity)) {
                Log("Not renderable");
                return;
            }
            auto renderableInstance = renderableManager->getInstance(entity);
            renderableManager->setPriority(renderableInstance, priority);
        }

        EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getBoundingBox(TRenderableManager *tRenderableManager, EntityId entityId) {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            
            if (!renderableManager->hasComponent(entity)) {
                Log("Not renderable");
                return Aabb3{ 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
            }
            auto renderableInstance = renderableManager->getInstance(entity);
            auto boundingBox = renderableManager->getAxisAlignedBoundingBox(renderableInstance);
            
            return Aabb3{boundingBox.center.x, boundingBox.center.y, boundingBox.center.z, boundingBox.halfExtent.x, boundingBox.halfExtent.y, boundingBox.halfExtent.z};

        }

    }
}