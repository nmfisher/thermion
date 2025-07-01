
#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE TOverlayManager *OverlayManager_create(
    TEngine *tEngine,
    TRenderer *tRenderer,
    TView *tView,
    TScene *tScene,
    TRenderTarget *tRenderTarget
);

EMSCRIPTEN_KEEPALIVE void OverlayManager_addComponent(
    TOverlayManager *tOverlayManager,
    EntityId entityId,
    TMaterialInstance *tMaterialInstance
);

EMSCRIPTEN_KEEPALIVE void OverlayManager_removeComponent(
    TOverlayManager *tOverlayManager,
    EntityId entityId
);


#ifdef __cplusplus
}
#endif