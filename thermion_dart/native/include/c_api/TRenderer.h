#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"
#include "TTexture.h"

#ifdef __cplusplus
extern "C"
{
#endif

// Timing for one frame, copied from filament::Renderer::FrameInfo.
// Times are nanoseconds on std::steady_clock. A field holds
// TFRAME_INFO_INVALID when the backend does not report it and
// TFRAME_INFO_PENDING when it is not yet available; gpuFrameComplete is 0
// when the backend does not report it.
#define TFRAME_INFO_INVALID -1
#define TFRAME_INFO_PENDING -2

struct TFrameInfo {
    uint32_t frameId;
    int64_t gpuFrameDuration;
    int64_t denoisedGpuFrameDuration;
    int64_t beginFrame;
    int64_t endFrame;
    int64_t backendBeginFrame;
    int64_t backendEndFrame;
    int64_t gpuFrameComplete;
};
typedef struct TFrameInfo TFrameInfo;

EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptions(TRenderer *tRenderer, double clearR, double clearG, double clearB, double clearA, uint8_t clearStencil, bool clear, bool discard);
EMSCRIPTEN_KEEPALIVE bool Renderer_beginFrame(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos);
EMSCRIPTEN_KEEPALIVE void Renderer_endFrame(TRenderer *tRenderer);
EMSCRIPTEN_KEEPALIVE void Renderer_render(TRenderer *tRenderer, TView *tView);
EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneView(TRenderer *tRenderer, TView *tView);
EMSCRIPTEN_KEEPALIVE void Renderer_readPixels(
    TRenderer *tRenderer,
    uint32_t width, uint32_t height, uint32_t xOffset, uint32_t yOffset,
    TRenderTarget *tRenderTarget,
    TPixelDataFormat tPixelBufferFormat,
    TPixelDataType tPixelDataType,
    uint8_t *out,
    size_t outLength
);
EMSCRIPTEN_KEEPALIVE void Renderer_setFrameInterval(
    TRenderer *tRenderer,
    float headRoomRatio,
    float scaleRate,
    uint8_t history, 
    uint8_t interval 
);

// Returns Filament's reported upper bound for the frame timing history.
EMSCRIPTEN_KEEPALIVE size_t Renderer_getMaxFrameHistorySize(TRenderer *tRenderer);

// Copies up to [capacity] of the most recent frames into [out], newest
// first, and returns the number copied. Filament keeps at most
// Renderer::getMaxFrameHistorySize() frames.
EMSCRIPTEN_KEEPALIVE size_t Renderer_getFrameInfoHistory(TRenderer *tRenderer, TFrameInfo *out, size_t capacity);



#ifdef __cplusplus
}
#endif
