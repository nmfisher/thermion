#ifndef _T_RENDERTARGET_H
#define _T_RENDERTARGET_H

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"
#include "TTexture.h"
#include "ResourceBuffer.hpp"
#include "MathUtils.hpp"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE TRenderTarget *RenderTarget_create(
    TEngine *tEngine,
    uint32_t width,
    uint32_t height,
    TTexture *color,
    TTexture *depth
);

EMSCRIPTEN_KEEPALIVE void RenderTarget_destroy(
    TEngine *tEngine,
    TRenderTarget *tRenderTarget
);

#ifdef __cplusplus
}
#endif

#endif