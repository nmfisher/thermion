#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"
#include "TTexture.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptions(TRenderer *tRenderer, double clearR, double clearG, double clearB, double clearA, uint8_t clearStencil, bool clear, bool discard);
EMSCRIPTEN_KEEPALIVE bool Renderer_beginFrame(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos);
EMSCRIPTEN_KEEPALIVE void Renderer_endFrame(TRenderer *tRenderer);
EMSCRIPTEN_KEEPALIVE void Renderer_render(TRenderer *tRenderer, TView *tView);
EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneView(TRenderer *tRenderer, TView *tView);
// Completion transfers a native buffer after Filament finishes writing it.
// Submit/end/flush the frame before waiting. Release the result exactly once
// with Renderer_copyPixelsAndRelease, using the same length as this request.
EMSCRIPTEN_KEEPALIVE void Renderer_readPixels(
    TRenderer *tRenderer,
    uint32_t width, uint32_t height, uint32_t xOffset, uint32_t yOffset,
    TRenderTarget *tRenderTarget,
    TPixelDataFormat tPixelBufferFormat,
    TPixelDataType tPixelDataType,
    size_t outLength,
    void (*onComplete)(uint8_t*)
);
// Synchronously copies a completed readback into out and releases its storage.
// out must have length bytes. Neither pointer may be used by another call.
EMSCRIPTEN_KEEPALIVE void Renderer_copyPixelsAndRelease(uint8_t *pixels, uint8_t *out, size_t length);
EMSCRIPTEN_KEEPALIVE void Renderer_setFrameInterval(
    TRenderer *tRenderer,
    float headRoomRatio,
    float scaleRate,
    uint8_t history, 
    uint8_t interval 
);



#ifdef __cplusplus
}
#endif
