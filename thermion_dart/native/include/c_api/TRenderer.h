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



#ifdef __cplusplus
}
#endif
