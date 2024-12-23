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
#ifdef __cplusplus
}
#endif

