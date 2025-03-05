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

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex, TMaterialInstance *tMaterialInstance)
        {
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            auto materialInstance = reinterpret_cast<MaterialInstance *>(tMaterialInstance);
            renderableManager->setMaterialInstanceAt(renderableInstance, primitiveIndex, materialInstance);
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

        EMSCRIPTEN_KEEPALIVE void RenderableManager_setPriority(TRenderableManager *tRenderableManager, EntityId entityId, int priority) { 
            auto *renderableManager = reinterpret_cast<filament::RenderableManager *>(tRenderableManager);
            const auto &entity = utils::Entity::import(entityId);
            auto renderableInstance = renderableManager->getInstance(entity);
            renderableManager->setPriority(renderableInstance, priority);
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
    }
}