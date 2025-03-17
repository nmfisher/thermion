#ifndef _T_RENDERER_H
#define _T_RENDERER_H

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"

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
    TView *tView,
    TRenderTarget *tRenderTarget,
    TPixelDataFormat tPixelBufferFormat,
    TPixelDataType tPixelDataType,
    uint8_t *out
);



#ifdef __cplusplus
}
#endif
#endif
