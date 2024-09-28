#pragma once

#ifdef __cplusplus
namespace thermion {
extern "C"
{
#endif

#include "ThermionDartApi.h"

struct TViewport { 
    int32_t left;
    int32_t bottom;
    uint32_t width;
    uint32_t height;
};
typedef struct TViewport TViewport;

enum ToneMapping
{
    ACES,
    FILMIC,
    LINEAR
};

// View
EMSCRIPTEN_KEEPALIVE TViewport View_getViewport(TView *view);
EMSCRIPTEN_KEEPALIVE void View_updateViewport(TView *view, uint32_t width, uint32_t height);
EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView *view, TRenderTarget *renderTarget);
EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView *view, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_updateViewport(TView* tView, uint32_t width, uint32_t height);
EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView* tView, TRenderTarget* tRenderTarget);
EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setPostProcessing(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabled(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setShadowType(TView* tView, int shadowType);
EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptions(TView* tView, float penumbraScale, float penumbraRatioScale);
EMSCRIPTEN_KEEPALIVE void View_setBloom(TView* tView, float strength);
EMSCRIPTEN_KEEPALIVE void View_setToneMapping(TView* tView, TEngine* tEngine, ToneMapping toneMapping);
EMSCRIPTEN_KEEPALIVE void View_setAntiAliasing(TView *tView, bool msaa, bool fxaa, bool taa);
EMSCRIPTEN_KEEPALIVE void View_setLayerEnabled(TView *tView, int layer, bool visible);
EMSCRIPTEN_KEEPALIVE void View_setCamera(TView *tView, TCamera *tCamera);
EMSCRIPTEN_KEEPALIVE TCamera* View_getCamera(TView *tView);

#ifdef __cplusplus
}
}
#endif
