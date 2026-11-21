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
	EMSCRIPTEN_KEEPALIVE void RenderManager_setMaterialOverride(TRenderManager *tRenderManager, TView *tView, TMaterialInstance *tMaterialInstance);
	EMSCRIPTEN_KEEPALIVE void RenderManager_renderView(TRenderManager *tRenderManager, TView *tView, bool standalone);

	// Web worker attachment and pause controls. Dart calls these only on web;
	// drawing is driven by the worker's animation frames, without frame requests.
	EMSCRIPTEN_KEEPALIVE void RenderManager_attachToJobThread(TJobThread *jobThread, TRenderManager *tRenderer);
	EMSCRIPTEN_KEEPALIVE void RenderManager_detachFromJobThread(TJobThread *jobThread, TRenderManager *tRenderManager);
	EMSCRIPTEN_KEEPALIVE void RenderManager_setPaused(TRenderManager *tRenderer, bool paused);
	EMSCRIPTEN_KEEPALIVE void RenderManager_setTargetFps(TRenderManager *tRenderManager, int fps);

	struct TCaptureViewRequest {
		TView *view;
		TRenderTarget *renderTarget;
		uint32_t width;
		uint32_t height;
		uint32_t format;
		uint32_t type;
	};
	typedef struct TCaptureViewRequest TCaptureViewRequest;

	// Atomically runs beginFrame -> render(views) -> readPixels(views) -> endFrame
	// while holding the render manager mutex. Native owns readback buffers until
	// Filament invokes each PixelBufferDescriptor callback, then passes a
	// TCaptureResult* (or NULL if validation/beginFrame failed) to onComplete.
	// Non-null results must be released with CaptureResult_destroy.
	EMSCRIPTEN_KEEPALIVE void RenderManager_capture(
		TRenderManager *tRenderManager,
		TSwapChain *tSwapChain,
		uint64_t frameTimeInNanos,
		bool render,
		const TCaptureViewRequest *requests,
		uint32_t viewCount,
		void (*onComplete)(TCaptureResult *)
	);
	EMSCRIPTEN_KEEPALIVE uint8_t *CaptureResult_getPixels(TCaptureResult *tCaptureResult, uint32_t index);
	EMSCRIPTEN_KEEPALIVE uint32_t CaptureResult_getByteLength(TCaptureResult *tCaptureResult, uint32_t index);
	EMSCRIPTEN_KEEPALIVE void CaptureResult_destroy(TCaptureResult *tCaptureResult);

#ifdef __cplusplus
}
#endif
