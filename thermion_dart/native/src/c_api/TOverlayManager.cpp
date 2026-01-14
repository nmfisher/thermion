#include "Log.hpp"

#include <filament/Camera.h>
#include <filament/Engine.h>
#include <filament/View.h>
#include <utils/Entity.h>

#include "c_api/TOverlayManager.h"
#include "components/OverlayComponentManager.hpp"

using namespace thermion;

extern "C"
{

EMSCRIPTEN_KEEPALIVE TOverlayManager *OverlayManager_create(TEngine *tEngine) {
    auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
    auto *overlayManager = new OverlayComponentManager(engine);
    return reinterpret_cast<TOverlayManager *>(overlayManager);
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_destroy(TOverlayManager *tOverlayManager) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    delete overlayManager;
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_initialize(
    TOverlayManager *tOverlayManager,
    uint32_t width,
    uint32_t height) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    overlayManager->initialize(width, height);
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_setViewport(TOverlayManager *tOverlayManager, uint32_t width, uint32_t height) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    overlayManager->setViewport(width, height);
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_setCamera(
    TOverlayManager *tOverlayManager,
    TCamera *tCamera) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    auto *camera = reinterpret_cast<filament::Camera *>(tCamera);
    overlayManager->setCamera(camera);
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_addHighlight(
    TOverlayManager *tOverlayManager,
    EntityId entityId,
    TVertexBuffer *tVertexBuffer,
    TIndexBuffer *tIndexBuffer,
    uint32_t indexCount,
    float outlineWidth,
    float r,
    float g,
    float b) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    auto *vertexBuffer = reinterpret_cast<filament::VertexBuffer *>(tVertexBuffer);
    auto *indexBuffer = reinterpret_cast<filament::IndexBuffer *>(tIndexBuffer);
    overlayManager->addHighlight(
        utils::Entity::import(entityId),
        vertexBuffer,
        indexBuffer,
        indexCount,
        outlineWidth, r, g, b);
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_removeHighlight(TOverlayManager *tOverlayManager, EntityId entityId) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    overlayManager->removeHighlight(utils::Entity::import(entityId));
}

EMSCRIPTEN_KEEPALIVE TView *OverlayManager_getSilhouetteView(
    TOverlayManager *tOverlayManager) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    return reinterpret_cast<TView *>(overlayManager->getSilhouetteView());
}

EMSCRIPTEN_KEEPALIVE TView *OverlayManager_getOverlayView(
    TOverlayManager *tOverlayManager) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    return reinterpret_cast<TView *>(overlayManager->getOverlayView());
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_setSilhouetteTexture(
    TOverlayManager *tOverlayManager,
    TTexture *tSilhouetteTexture) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    auto *silhouetteTexture = reinterpret_cast<filament::Texture *>(tSilhouetteTexture);
    overlayManager->setSilhouetteTexture(silhouetteTexture);
}

EMSCRIPTEN_KEEPALIVE bool OverlayManager_hasHighlights(
    TOverlayManager *tOverlayManager) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    return overlayManager->hasHighlights();
}

EMSCRIPTEN_KEEPALIVE bool OverlayManager_isInitialized(
    TOverlayManager *tOverlayManager) {
    auto *overlayManager = reinterpret_cast<OverlayComponentManager *>(tOverlayManager);
    return overlayManager->isInitialized();
}

}
