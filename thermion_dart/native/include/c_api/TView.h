#pragma once

#include "APIExport.h"

#ifdef __cplusplus
namespace thermion {
extern "C"
{
#endif

#include "APIBoundaryTypes.h"

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

typedef struct TToneMapper TToneMapper;

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

enum TLutFormat {
    INTEGER,
    FLOAT
};
typedef enum TLutFormat TLutFormat;

// View
EMSCRIPTEN_KEEPALIVE TViewport View_getViewport(TView *view);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createLinear(TEngine* tEngine);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createACES(TEngine* tEngine);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createACESLegacy(TEngine* tEngine);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createFilmic(TEngine* tEngine);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createPBRNeutral(TEngine* tEngine);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createAGX(TEngine* tEngine);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createAGXWithLook(TEngine* tEngine, int look);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createGeneric(TEngine* tEngine, float contrast, float midGrayIn, float midGrayOut, float hdrMax);
EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createDisplayRange(TEngine* tEngine);
EMSCRIPTEN_KEEPALIVE void ToneMapper_destroy(TToneMapper *toneMapper);

// ColorGrading Builder API
typedef struct TColorGradingBuilder TColorGradingBuilder;

EMSCRIPTEN_KEEPALIVE TColorGradingBuilder* ColorGradingBuilder_create();
EMSCRIPTEN_KEEPALIVE TColorGrading* ColorGradingBuilder_build(TColorGradingBuilder* builder, TEngine* engine);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_destroy(TColorGradingBuilder* builder);
EMSCRIPTEN_KEEPALIVE void ColorGrading_destroy(TEngine* engine, TColorGrading* colorGrading);

// Quality and format
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_quality(TColorGradingBuilder* builder, TQualityLevel level);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_format(TColorGradingBuilder* builder, TLutFormat format);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_dimensions(TColorGradingBuilder* builder, uint8_t dim);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_toneMapper(TColorGradingBuilder* builder, TToneMapper* toneMapper);

// Basic adjustments
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_exposure(TColorGradingBuilder* builder, float exposure);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_nightAdaptation(TColorGradingBuilder* builder, float adaptation);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_whiteBalance(TColorGradingBuilder* builder, float temperature, float tint);

// Color adjustments
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_contrast(TColorGradingBuilder* builder, float contrast);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_vibrance(TColorGradingBuilder* builder, float vibrance);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_saturation(TColorGradingBuilder* builder, float saturation);

// Advanced controls
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_channelMixer(TColorGradingBuilder* builder,
    float outRedR, float outRedG, float outRedB,
    float outGreenR, float outGreenG, float outGreenB,
    float outBlueR, float outBlueG, float outBlueB);

EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_shadowsMidtonesHighlights(TColorGradingBuilder* builder,
    float shadowsR, float shadowsG, float shadowsB, float shadowsW,
    float midtonesR, float midtonesG, float midtonesB, float midtonesW,
    float highlightsR, float highlightsG, float highlightsB, float highlightsW,
    float rangesX, float rangesY, float rangesZ, float rangesW);

EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_slopeOffsetPower(TColorGradingBuilder* builder,
    float slopeR, float slopeG, float slopeB,
    float offsetR, float offsetG, float offsetB,
    float powerR, float powerG, float powerB);

EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_curves(TColorGradingBuilder* builder,
    float shadowGammaR, float shadowGammaG, float shadowGammaB,
    float midPointR, float midPointG, float midPointB,
    float highlightScaleR, float highlightScaleG, float highlightScaleB);

// Flags
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_luminanceScaling(TColorGradingBuilder* builder, bool enabled);
EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_gamutMapping(TColorGradingBuilder* builder, bool enabled);

EMSCRIPTEN_KEEPALIVE void View_setColorGrading(TView *tView, TColorGrading *tColorGrading);
EMSCRIPTEN_KEEPALIVE TColorGrading* View_getColorGrading(TView *tView);
EMSCRIPTEN_KEEPALIVE void View_setBlendMode(TView *view, TBlendMode blendMode);
EMSCRIPTEN_KEEPALIVE void View_setViewport(TView *view, uint32_t width, uint32_t height);
EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView *view, TRenderTarget *renderTarget);
EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView *view, bool enabled);
EMSCRIPTEN_KEEPALIVE int32_t View_getVisibleRenderableCount(TView *view);
EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView* tView, TRenderTarget* tRenderTarget);
EMSCRIPTEN_KEEPALIVE TRenderTarget *View_getRenderTarget(TView* tView);
EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setPostProcessing(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabled(TView* tView, bool enabled);
EMSCRIPTEN_KEEPALIVE void View_setShadowType(TView* tView, int shadowType);
EMSCRIPTEN_KEEPALIVE int View_getShadowType(TView* tView);

/**
 * Options for DPCF and PCSS Shadowing.
 */
struct TSoftShadowOptions {
    float penumbraScale;
    float penumbraRatioScale;
    float maxPenumbraRatio;
    float maxSearchRadius;
};
typedef struct TSoftShadowOptions TSoftShadowOptions;

EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptions(TView* tView, TSoftShadowOptions options);
EMSCRIPTEN_KEEPALIVE TSoftShadowOptions View_getSoftShadowOptions(TView* tView);

/**
 * Options for VSM Shadowing.
 */
struct TVsmShadowOptions {
    uint8_t anisotropy;
    bool mipmapping;
    uint8_t msaaSamples;
    bool highPrecision;
    float minVarianceScale;
    float lightBleedReduction;
};
typedef struct TVsmShadowOptions TVsmShadowOptions;

EMSCRIPTEN_KEEPALIVE void View_setVsmShadowOptions(TView* tView, TVsmShadowOptions options);
EMSCRIPTEN_KEEPALIVE TVsmShadowOptions View_getVsmShadowOptions(TView* tView);

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

/**
 * Screen Space Cone Tracing (SSCT) options
 * Ambient shadows from dominant light
 */
struct TSsct {
    float lightConeRad = 1.0f;       //!< full cone angle in radian, between 0 and pi/2
    float shadowDistance = 0.3f;     //!< how far shadows can be cast
    float contactDistanceMax = 1.0f; //!< max distance for contact
    float intensity = 0.8f;          //!< intensity
    float lightDirectionX = 0.0f;    //!< light direction X
    float lightDirectionY = -1.0f;   //!< light direction Y
    float lightDirectionZ = 0.0f;    //!< light direction Z
    float depthBias = 0.01f;         //!< depth bias in world units (mitigate self shadowing)
    float depthSlopeBias = 0.01f;    //!< depth slope bias (mitigate self shadowing)
    uint8_t sampleCount = 4;         //!< tracing sample count, between 1 and 255
    uint8_t rayCount = 1;            //!< # of rays to trace, between 1 and 255
    bool enabled = false;            //!< enables or disables SSCT
};

enum TAmbientOcclusionType {
    SAO,
    GTAO
};
typedef enum TAmbientOcclusionType TAmbientOcclusionType;

/**
 * Ground Truth-based Ambient Occlusion (GTAO) options
 */
struct TGtao {
    uint8_t sampleSliceCount = 4;        //!< number of slices; higher values reduce noise
    uint8_t sampleStepsPerSlice = 3;     //!< integration steps per slice; higher values reduce bias
    float thicknessHeuristic = 0.004f;   //!< ignored when visibility bitmasks are enabled
    bool useVisibilityBitmasks = false;  //!< enables visibility bitmasks mode
    float constThickness = 0.5f;         //!< world-space thickness used by visibility bitmasks
    bool linearThickness = false;        //!< increases thickness with distance
};

/**
 * Options for ambient occlusion, Screen Space Cone Tracing (SSCT), and GTAO
 */
struct TAmbientOcclusionOptions {
    float radius = 0.3f;            //!< Ambient Occlusion radius in meters, between 0 and ~10
    float power = 1.0f;             //!< Controls ambient occlusion's contrast. Must be positive
    float bias = 0.0005f;           //!< Self-occlusion bias in meters. Use to avoid self-occlusion. Between 0 and a few mm
    float resolution = 0.5f;        //!< How each dimension of the AO buffer is scaled. Must be either 0.5 or 1.0
    float intensity = 1.0f;         //!< Strength of the Ambient Occlusion effect
    float bilateralThreshold = 0.05f; //!< depth distance that constitute an edge for filtering
    TQualityLevel quality = LOW;    //!< affects # of samples used for AO
    TQualityLevel lowPassFilter = MEDIUM; //!< affects AO smoothness
    TQualityLevel upsampling = LOW; //!< affects AO buffer upsampling quality
    bool enabled = false;           //!< enables or disables screen-space ambient occlusion
    bool bentNormals = false;       //!< enables bent normals computation from AO, and specular AO
    float minHorizonAngleRad = 0.0f; //!< min angle in radian to consider
    TSsct ssct;
    TGtao gtao;
    TAmbientOcclusionType aoType = SAO; //!< ambient occlusion algorithm
};

typedef struct TAmbientOcclusionOptions TAmbientOcclusionOptions;

EMSCRIPTEN_KEEPALIVE void View_setAmbientOcclusionOptions(TView *tView, TAmbientOcclusionOptions options);
EMSCRIPTEN_KEEPALIVE TAmbientOcclusionOptions View_getAmbientOcclusionOptions(TView *tView);

EMSCRIPTEN_KEEPALIVE void View_setFogOptions(TView *tView, TFogOptions tFogOptions);
EMSCRIPTEN_KEEPALIVE TFogOptions View_getFogOptions(TView *tView);
EMSCRIPTEN_KEEPALIVE void View_setTransparentPickingEnabled(TView *tView, bool enabled);
EMSCRIPTEN_KEEPALIVE bool View_isTransparentPickingEnabled(TView *tView);

typedef void (*PickCallback)(uint32_t requestId, EntityId entityId, float depth, float fragX, float fragY, float fragZ);
EMSCRIPTEN_KEEPALIVE void View_pick(TView* tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback);
EMSCRIPTEN_KEEPALIVE void View_setName(TView* tView, const char *name);
EMSCRIPTEN_KEEPALIVE const char *View_getName(TView* tView);

#ifdef __cplusplus
}
}
#endif
