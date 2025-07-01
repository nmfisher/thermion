#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include "Log.hpp"

#include <filament/Engine.h>
#include <filament/RenderTarget.h>
#include <filament/Renderer.h>
#include <filament/View.h>
#include <utils/Entity.h>

#include "c_api/TOverlayManager.h"
#include "components/OverlayComponentManager.hpp"

using namespace thermion;

extern "C"
{


EMSCRIPTEN_KEEPALIVE TOverlayManager *OverlayManager_create(TEngine *tEngine, TRenderer *tRenderer, TView *tView, TScene *tScene, TRenderTarget *tRenderTarget) {
    auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
    auto *view = reinterpret_cast<filament::View *>(tView);
    auto *scene = reinterpret_cast<filament::Scene *>(tScene);
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *renderTarget = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
    auto *overlayManager = new OverlayComponentManager(engine, view, scene, renderTarget, renderer);
    return reinterpret_cast<TOverlayManager *>(overlayManager);
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_addComponent(TOverlayManager *tOverlayManager, EntityId entityId, TMaterialInstance *tMaterialInstance) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    auto *materialInstance = reinterpret_cast<filament::MaterialInstance *>(tMaterialInstance);
    overlayManager->addOverlayComponent(utils::Entity::import(entityId), materialInstance);
}


EMSCRIPTEN_KEEPALIVE void OverlayManager_removeComponent(TOverlayManager *tOverlayManager, EntityId entityId) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    overlayManager->removeOverlayComponent(utils::Entity::import(entityId));
}

}