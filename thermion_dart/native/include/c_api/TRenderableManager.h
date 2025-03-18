#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

    EMSCRIPTEN_KEEPALIVE void RenderableManager_setMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex, TMaterialInstance *tMaterialInstance);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setPriority(TRenderableManager *tRenderableManager, EntityId entityId, int priority);
    EMSCRIPTEN_KEEPALIVE TMaterialInstance *RenderableManager_getMaterialInstanceAt(TRenderableManager *tRenderableManager, EntityId entityId, int primitiveIndex);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_isRenderable(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_hasComponent(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_empty(TRenderableManager *tRenderableManager);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_getLightChannel(TRenderableManager *tRenderableManager, EntityId entityId, unsigned int channel);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_isShadowCaster(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setCastShadows(TRenderableManager *tRenderableManager, EntityId entityId, bool castShadows);
    EMSCRIPTEN_KEEPALIVE void RenderableManager_setReceiveShadows(TRenderableManager *tRenderableManager, EntityId entityId, bool receiveShadows);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_isShadowReceiver(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE bool RenderableManager_getFogEnabled(TRenderableManager *tRenderableManager, EntityId entityId);
    EMSCRIPTEN_KEEPALIVE Aabb3 RenderableManager_getAabb(TRenderableManager *tRenderableManager, EntityId entityId);

#ifdef __cplusplus
}
#endif