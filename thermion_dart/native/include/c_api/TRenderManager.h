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

	// Web path. On native these are either no-ops (attach) or equivalent to a
	// synchronous render (requestRender). Dart branches on FILAMENT_SINGLE_THREADED
	// and only calls these on the web build.
	EMSCRIPTEN_KEEPALIVE void RenderManager_requestRender(TRenderManager *tRenderer);
	EMSCRIPTEN_KEEPALIVE void RenderManager_attachToRenderThread(TRenderManager *tRenderer);
	EMSCRIPTEN_KEEPALIVE void RenderManager_detachFromRenderThread(TRenderManager *tRenderManager);
	EMSCRIPTEN_KEEPALIVE void RenderManager_setPaused(TRenderManager *tRenderer, bool paused);

#ifdef __cplusplus
}
#endif
