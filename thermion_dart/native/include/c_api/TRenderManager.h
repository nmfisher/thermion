#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE TRenderManager *RenderManager_create(TEngine *tEngine, TRenderer *tRenderer);
	EMSCRIPTEN_KEEPALIVE void RenderManager_destroy(TRenderManager *tRenderer);
	EMSCRIPTEN_KEEPALIVE void RenderManager_addAnimationManager(TRenderManager *tRenderer, TAnimationManager *tAnimationManager);
	EMSCRIPTEN_KEEPALIVE void RenderManager_removeAnimationManager(TRenderManager *tRenderer, TAnimationManager *tAnimationManager);
	
	EMSCRIPTEN_KEEPALIVE void RenderManager_render(TRenderManager *tRenderer, uint64_t frameTimeInNanos);
	EMSCRIPTEN_KEEPALIVE void RenderManager_setRenderable(TRenderManager *tRenderer, TSwapChain *swapChain, TView **views, uint8_t numViews);
	EMSCRIPTEN_KEEPALIVE void RenderManager_removeSwapChain(TRenderManager *tRenderer, TSwapChain *swapChain);

	// Web worker attachment and pause controls. Dart calls these only on web;
	// drawing is driven by the worker's animation frames, without frame requests.
	EMSCRIPTEN_KEEPALIVE void RenderManager_attachToRenderThread(TRenderManager *tRenderer);
	EMSCRIPTEN_KEEPALIVE void RenderManager_detachFromRenderThread(TRenderManager *tRenderManager);
	EMSCRIPTEN_KEEPALIVE void RenderManager_setPaused(TRenderManager *tRenderer, bool paused);

#ifdef __cplusplus
}
#endif
