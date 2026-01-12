
#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE TOverlayManager *OverlayManager_create(TEngine *tEngine);

EMSCRIPTEN_KEEPALIVE void OverlayManager_destroy(TOverlayManager *tOverlayManager);

EMSCRIPTEN_KEEPALIVE void OverlayManager_initialize(
    TOverlayManager *tOverlayManager,
    uint32_t width,
    uint32_t height,
    intptr_t hardwareTextureId
);

EMSCRIPTEN_KEEPALIVE void OverlayManager_addHighlight(
    TOverlayManager *tOverlayManager,
    EntityId entityId,
    TVertexBuffer *tVertexBuffer,
    TIndexBuffer *tIndexBuffer,
    uint32_t indexCount,
    float outlineWidth,
    float r,
    float g,
    float b
);

EMSCRIPTEN_KEEPALIVE void OverlayManager_removeHighlight(
    TOverlayManager *tOverlayManager,
    EntityId entityId
);

EMSCRIPTEN_KEEPALIVE void OverlayManager_setViewport(
    TOverlayManager *tOverlayManager,
    uint32_t width,
    uint32_t height
);

EMSCRIPTEN_KEEPALIVE void OverlayManager_setCamera(
    TOverlayManager *tOverlayManager,
    TCamera *tCamera
);

EMSCRIPTEN_KEEPALIVE TView *OverlayManager_getSilhouetteView(
    TOverlayManager *tOverlayManager
);

EMSCRIPTEN_KEEPALIVE TView *OverlayManager_getOverlayView(
    TOverlayManager *tOverlayManager
);

EMSCRIPTEN_KEEPALIVE TTexture *OverlayManager_getOverlayTexture(
    TOverlayManager *tOverlayManager
);

EMSCRIPTEN_KEEPALIVE bool OverlayManager_hasHighlights(
    TOverlayManager *tOverlayManager
);

EMSCRIPTEN_KEEPALIVE bool OverlayManager_isInitialized(
    TOverlayManager *tOverlayManager
);

#ifdef __cplusplus
}
#endif
