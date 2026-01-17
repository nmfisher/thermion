#include "Log.hpp"

#include <filament/Camera.h>
#include <filament/Engine.h>
#include <filament/View.h>
#include <utils/Entity.h>

#include "c_api/TOverlayManager.h"


extern "C"
{

EMSCRIPTEN_KEEPALIVE TOverlayManager *OverlayManager_create(TEngine *tEngine) {
    return nullptr;
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_destroy(TOverlayManager *tOverlayManager) {
    
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_initialize(
    TOverlayManager *tOverlayManager,
    uint32_t width,
    uint32_t height,
    intptr_t hardwareTextureId) {
    
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_setViewport(TOverlayManager *tOverlayManager, uint32_t width, uint32_t height) {
    
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_setCamera(
    TOverlayManager *tOverlayManager,
    TCamera *tCamera) {
    
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
    
}

EMSCRIPTEN_KEEPALIVE void OverlayManager_removeHighlight(TOverlayManager *tOverlayManager, EntityId entityId) {
    
}

EMSCRIPTEN_KEEPALIVE TView *OverlayManager_getSilhouetteView(
    TOverlayManager *tOverlayManager) {
    return nullptr;
}

EMSCRIPTEN_KEEPALIVE TView *OverlayManager_getOverlayView(
    TOverlayManager *tOverlayManager) {
    return nullptr;
}

EMSCRIPTEN_KEEPALIVE TTexture *OverlayManager_getOverlayTexture(
    TOverlayManager *tOverlayManager) {
return nullptr;
}

EMSCRIPTEN_KEEPALIVE bool OverlayManager_hasHighlights(
    TOverlayManager *tOverlayManager) {
return false;
}

EMSCRIPTEN_KEEPALIVE bool OverlayManager_isInitialized(
    TOverlayManager *tOverlayManager) {
    return false;
}

}
