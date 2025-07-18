#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE TRenderTicker *RenderTicker_create(TEngine *tEngine, TRenderer *tRenderer);
	EMSCRIPTEN_KEEPALIVE void RenderTicker_destroy(TRenderTicker *tRenderTicker);
	EMSCRIPTEN_KEEPALIVE void RenderTicker_addAnimationManager(TRenderTicker *tRenderTicker, TAnimationManager *tAnimationManager);
	EMSCRIPTEN_KEEPALIVE void RenderTicker_removeAnimationManager(TRenderTicker *tRenderTicker, TAnimationManager *tAnimationManager);
	
	EMSCRIPTEN_KEEPALIVE void RenderTicker_render(TRenderTicker *tRenderTicker, uint64_t frameTimeInNanos);
	EMSCRIPTEN_KEEPALIVE void RenderTicker_setRenderable(TRenderTicker *tRenderTicker, TSwapChain *swapChain, TView **views, uint8_t numViews);	
	EMSCRIPTEN_KEEPALIVE void RenderTicker_removeSwapChain(TRenderTicker *tRenderTicker, TSwapChain *swapChain);	
	EMSCRIPTEN_KEEPALIVE void RenderTicker_setOverlayManager(TRenderTicker *tRenderTicker, TOverlayManager *tOverlayManager);
	
#ifdef __cplusplus
}
#endif
