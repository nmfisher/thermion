#pragma once

#ifdef __cplusplus
namespace thermion {
extern "C"
{
#endif

#include "APIBoundaryTypes.h"
#include "APIExport.h"

struct TViewport { 
    int32_t left;
    int32_t bottom;
    uint32_t width;
    uint32_t height;
};
typedef struct TViewport TViewport;

/**
 * Copied from FogOptions in View.h
 */
struct TFogOptions {
    float distance = 0.0f;
    float cutOffDistance = INFINITY;
    float maximumOpacity = 1.0f;
    float height = 0.0f;
    float heightFalloff = 1.0f;
    float density = 0.1f;
    float inScatteringStart = 0.0f;
    float inScatteringSize = -1.0f;
    TTexture* skyColor = nullptr;
    float linearColorR = 1.0;
    float linearColorG = 1.0;
    float linearColorB = 1.0;
    bool fogColorFromIbl = 0;
    bool enabled = 0;
};

enum TToneMapping
{
    ACES,
    FILMIC,
    LINEAR
};
typedef enum TToneMapping TToneMapping;

// copied from Options.h
enum TQualityLevel { 
    LOW,
    MEDIUM,
    HIGH,
    ULTRA
};
typedef enum TQualityLevel TQualityLevel;

enum TBlendMode {
    OPAQUE,
    TRANSLUCENT
};
typedef enum TBlendMode TBlendMode;

// View
EMSCRIPTEN_KEEPALIVE TViewport View_getViewport(TView *view);
EMSCRIPTEN_KEEPALIVE TColorGrading *ColorGrading_create(TEngine* tEngine, TToneMapping toneMapping);
EMSCRIPTEN_KEEPALIVE void View_setColorGrading(TView *tView, TColorGrading *tColorGrading);
EMSCRIPTEN_KEEPALIVE void View_setBlendMode(TView *view, TBlendMode blendMode);
EMSCRIPTEN_KEEPALIVE void View_setViewport(TView *view, uint32_t width, uint32_t height);
EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView *view, TRenderTarget *renderTarget);
EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView *view, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView* tView, TRenderTarget* tRenderTarget);
EMSCRIPTEN_KEEPALIVE TRenderTarget *View_getRenderTarget(TView* tView);
EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setPostProcessing(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabled(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setShadowType(TView* tView, int shadowType);
EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptions(TView* tView, float penumbraScale, float penumbraRatioScale);
EMSCRIPTEN_KEEPALIVE void View_setBloom(TView* tView, bool enabled, float strength);
EMSCRIPTEN_KEEPALIVE void View_setRenderQuality(TView* tView, TQualityLevel qualityLevel);
EMSCRIPTEN_KEEPALIVE void View_setAntiAliasing(TView *tView, bool msaa, bool fxaa, bool taa);
EMSCRIPTEN_KEEPALIVE void View_setLayerEnabled(TView *tView, int layer, bool visible);
EMSCRIPTEN_KEEPALIVE void View_setCamera(TView *tView, TCamera *tCamera);
EMSCRIPTEN_KEEPALIVE TScene* View_getScene(TView *tView);
EMSCRIPTEN_KEEPALIVE TCamera* View_getCamera(TView *tView);
EMSCRIPTEN_KEEPALIVE void View_setStencilBufferEnabled(TView *tView, bool enabled);
EMSCRIPTEN_KEEPALIVE bool View_isStencilBufferEnabled(TView *tView);
EMSCRIPTEN_KEEPALIVE void View_setDitheringEnabled(TView *tView, bool enabled);
EMSCRIPTEN_KEEPALIVE bool View_isDitheringEnabled(TView *tView);
EMSCRIPTEN_KEEPALIVE void View_setScene(TView *tView, TScene *tScene);
EMSCRIPTEN_KEEPALIVE void View_setFrontFaceWindingInverted(TView *tView, bool inverted);
EMSCRIPTEN_KEEPALIVE void View_setFogOptions(TView *tView, TFogOptions tFogOptions);
EMSCRIPTEN_KEEPALIVE void View_setTransparentPickingEnabled(TView *tView, bool enabled);
EMSCRIPTEN_KEEPALIVE bool View_isTransparentPickingEnabled(TView *tView);

typedef void (*PickCallback)(uint32_t requestId, EntityId entityId, float depth, float fragX, float fragY, float fragZ);
EMSCRIPTEN_KEEPALIVE void View_pick(TView* tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback);
EMSCRIPTEN_KEEPALIVE void View_setName(TView* tView, const char *name);

#ifdef __cplusplus
}
}
#endif
