#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE TRenderTicker *RenderTicker_create(TRenderer *tRenderer, TSceneManager *tSceneManager);
	EMSCRIPTEN_KEEPALIVE void RenderTicker_render(TRenderTicker *tRenderTicker, uint64_t frameTimeInNanos);
	EMSCRIPTEN_KEEPALIVE void RenderTicker_setRenderable(TRenderTicker *tFilamentRender, TSwapChain *swapChain, TView **views, uint8_t numViews);	
	
#ifdef __cplusplus
}
#endif
