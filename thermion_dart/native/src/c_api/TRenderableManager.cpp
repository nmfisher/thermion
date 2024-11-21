
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
    }
}