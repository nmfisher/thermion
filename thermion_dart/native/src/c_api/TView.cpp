

#include <filament/View.h>
#include <filament/Viewport.h>
#include <filament/Engine.h>
#include <filament/ToneMapper.h>
#include <filament/ColorGrading.h>
#include <filament/Camera.h>

#include "c_api/TView.h"
#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;

#endif

        EMSCRIPTEN_KEEPALIVE void View_setBlendMode(TView *tView, TBlendMode tBlendMode)
        {
            auto view = reinterpret_cast<View *>(tView);
            view->setBlendMode(static_cast<filament::View::BlendMode>(tBlendMode));
        }

        EMSCRIPTEN_KEEPALIVE TViewport View_getViewport(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            auto &vp = view->getViewport();
            TViewport tvp;
            tvp.left = vp.left;
            tvp.bottom = vp.bottom;
            tvp.width = vp.width;
            tvp.height = vp.height;
            return tvp;
        }

        EMSCRIPTEN_KEEPALIVE void View_setViewport(TView *tView, uint32_t width, uint32_t height)
        {
            auto view = reinterpret_cast<View *>(tView);
            view->setViewport({0, 0, width, height});
            TRACE("Set viewport to %dx%d", width, height);
        }

        EMSCRIPTEN_KEEPALIVE TRenderTarget *View_getRenderTarget(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            auto tRenderTarget = reinterpret_cast<TRenderTarget *>(view->getRenderTarget());
            return tRenderTarget;
        }

        EMSCRIPTEN_KEEPALIVE void View_setRenderTarget(TView *tView, TRenderTarget *tRenderTarget)
        {
            auto view = reinterpret_cast<View *>(tView);
            auto renderTarget = reinterpret_cast<RenderTarget *>(tRenderTarget);
            view->setRenderTarget(renderTarget);
        }

        EMSCRIPTEN_KEEPALIVE void View_setFrustumCullingEnabled(TView *tView, bool enabled)
        {
            auto view = reinterpret_cast<View *>(tView);
            view->setFrustumCullingEnabled(enabled);
        }

        EMSCRIPTEN_KEEPALIVE int32_t View_getVisibleRenderableCount(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            return view->getVisibleRenderableCount();
        }

        EMSCRIPTEN_KEEPALIVE void View_setPostProcessing(TView *tView, bool enabled)
        {
            auto view = reinterpret_cast<View *>(tView);
            view->setPostProcessingEnabled(enabled);
            TRACE("Set postprocessing enabled : %d", enabled);
        }

        EMSCRIPTEN_KEEPALIVE void View_setShadowsEnabled(TView *tView, bool enabled)
        {
            auto view = reinterpret_cast<View *>(tView);
            view->setShadowingEnabled(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void View_setShadowType(TView *tView, int shadowType)
        {
            auto view = reinterpret_cast<View *>(tView);
            view->setShadowType((ShadowType)shadowType);
        }

        EMSCRIPTEN_KEEPALIVE int View_getShadowType(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            return static_cast<int>(view->getShadowType());
        }

        EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptions(TView *tView, TSoftShadowOptions options)
        {
            auto view = reinterpret_cast<View *>(tView);
            SoftShadowOptions opts;
            opts.penumbraRatioScale = options.penumbraRatioScale;
            opts.penumbraScale = options.penumbraScale;
            opts.maxPenumbraRatio = options.maxPenumbraRatio;
            opts.maxSearchRadius = options.maxSearchRadius;
            view->setSoftShadowOptions(opts);
        }

        EMSCRIPTEN_KEEPALIVE TSoftShadowOptions View_getSoftShadowOptions(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            auto options = view->getSoftShadowOptions();
            TSoftShadowOptions tOptions;
            tOptions.penumbraRatioScale = options.penumbraRatioScale;
            tOptions.penumbraScale = options.penumbraScale;
            tOptions.maxPenumbraRatio = options.maxPenumbraRatio;
            tOptions.maxSearchRadius = options.maxSearchRadius;
            return tOptions;
        }

        EMSCRIPTEN_KEEPALIVE void View_setVsmShadowOptions(TView *tView, TVsmShadowOptions options)
        {
            auto view = reinterpret_cast<View *>(tView);
            VsmShadowOptions opts;
            opts.anisotropy = options.anisotropy;
            opts.mipmapping = options.mipmapping;
            opts.msaaSamples = options.msaaSamples;
            opts.highPrecision = options.highPrecision;
            opts.minVarianceScale = options.minVarianceScale;
            opts.lightBleedReduction = options.lightBleedReduction;
            view->setVsmShadowOptions(opts);
        }

        EMSCRIPTEN_KEEPALIVE TVsmShadowOptions View_getVsmShadowOptions(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            auto options = view->getVsmShadowOptions();
            TVsmShadowOptions tOptions;
            tOptions.anisotropy = options.anisotropy;
            tOptions.mipmapping = options.mipmapping;
            tOptions.msaaSamples = options.msaaSamples;
            tOptions.highPrecision = options.highPrecision;
            tOptions.minVarianceScale = options.minVarianceScale;
            tOptions.lightBleedReduction = options.lightBleedReduction;
            return tOptions;
        }

        EMSCRIPTEN_KEEPALIVE void View_setBloom(TView *tView, bool enabled, float strength)
        {
            auto view = reinterpret_cast<View *>(tView);
            decltype(view->getBloomOptions()) opts;
            opts.enabled = enabled;
            opts.strength = strength;
            TRACE("Setting bloom options {.enabled = %d, strength = %f}", enabled, strength);
            view->setBloomOptions(opts);
        }

        EMSCRIPTEN_KEEPALIVE void View_setColorGrading(TView *tView, TColorGrading *tColorGrading)
        {
            auto *view = reinterpret_cast<View *>(tView);
            auto *colorGrading = reinterpret_cast<ColorGrading *>(tColorGrading);
            view->setColorGrading(colorGrading);
        }

        EMSCRIPTEN_KEEPALIVE TColorGrading* View_getColorGrading(TView *tView)
        {
            auto *view = reinterpret_cast<View *>(tView);
            auto *cg = view->getColorGrading();
            if(!cg) {
                Log("Color grading null");
            } else { 
                Log("Color grading non-null");
            }
            return reinterpret_cast<TColorGrading*>(const_cast<ColorGrading *>(cg));
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createLinear(TEngine* tEngine)
        {
            TRACE("Creating LinearToneMapper");
            return reinterpret_cast<TToneMapper *>(new LinearToneMapper());
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createACES(TEngine* tEngine)
        {
            TRACE("Creating ACESToneMapper");
            return reinterpret_cast<TToneMapper *>(new ACESToneMapper());
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createACESLegacy(TEngine* tEngine)
        {
            TRACE("Creating ACESLegacyToneMapper");
            return reinterpret_cast<TToneMapper *>(new ACESLegacyToneMapper());
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createFilmic(TEngine* tEngine)
        {
            TRACE("Creating FilmicToneMapper");
            return reinterpret_cast<TToneMapper *>(new FilmicToneMapper());
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createPBRNeutral(TEngine* tEngine)
        {
            TRACE("Creating PBRNeutralToneMapper");
            return reinterpret_cast<TToneMapper *>(new PBRNeutralToneMapper());
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createAGX(TEngine* tEngine)
        {
            TRACE("Creating AgxToneMapper");
            return reinterpret_cast<TToneMapper *>(new AgxToneMapper());
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createAGXWithLook(TEngine* tEngine, int look)
        {
            TRACE("Creating AgxToneMapper with look %d", look);
            return reinterpret_cast<TToneMapper *>(new AgxToneMapper(static_cast<AgxToneMapper::AgxLook>(look)));
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createGeneric(TEngine* tEngine, float contrast, float midGrayIn, float midGrayOut, float hdrMax)
        {
            TRACE("Creating GenericToneMapper (contrast=%f, midGrayIn=%f, midGrayOut=%f, hdrMax=%f)", contrast, midGrayIn, midGrayOut, hdrMax);
            return reinterpret_cast<TToneMapper *>(new GenericToneMapper(contrast, midGrayIn, midGrayOut, hdrMax));
        }

        EMSCRIPTEN_KEEPALIVE TToneMapper *ToneMapper_createDisplayRange(TEngine* tEngine)
        {
            TRACE("Creating DisplayRangeToneMapper");
            return reinterpret_cast<TToneMapper *>(new DisplayRangeToneMapper());
        }

        EMSCRIPTEN_KEEPALIVE void ToneMapper_destroy(TToneMapper *toneMapper)
        {
            auto tm = reinterpret_cast<ToneMapper *>(toneMapper);
            delete tm;
            TRACE("Destroyed ToneMapper");
        }

        EMSCRIPTEN_KEEPALIVE TColorGrading *ColorGrading_create(TEngine *tEngine, TToneMapper *toneMapper)
        {
            auto engine = reinterpret_cast<Engine *>(tEngine);
            auto tm = reinterpret_cast<ToneMapper *>(toneMapper);

            TRACE("Creating ColorGrading with ToneMapper");
            auto colorGrading = ColorGrading::Builder().toneMapper(tm).build(*engine);

            return reinterpret_cast<TColorGrading *>(colorGrading);
        }

        // ============================================================================
        // ColorGrading Builder API
        // ============================================================================

        EMSCRIPTEN_KEEPALIVE TColorGradingBuilder* ColorGradingBuilder_create()
        {
            TRACE("Creating ColorGradingBuilder");
            auto builder = new ColorGrading::Builder();
            return reinterpret_cast<TColorGradingBuilder*>(builder);
        }

        EMSCRIPTEN_KEEPALIVE TColorGrading* ColorGradingBuilder_build(TColorGradingBuilder* tBuilder, TEngine* tEngine)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            auto engine = reinterpret_cast<Engine*>(tEngine);

            TRACE("Building ColorGrading");
            auto colorGrading = builder->build(*engine);

            return reinterpret_cast<TColorGrading*>(colorGrading);
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_destroy(TColorGradingBuilder* tBuilder)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            delete builder;
            TRACE("Destroyed ColorGradingBuilder");
        }

        EMSCRIPTEN_KEEPALIVE void ColorGrading_destroy(TEngine* tEngine, TColorGrading* tColorGrading)
        {
            auto engine = reinterpret_cast<Engine*>(tEngine);
            auto colorGrading = reinterpret_cast<ColorGrading*>(tColorGrading);
            engine->destroy(colorGrading);
            TRACE("Destroyed ColorGrading");
        }

        // Quality and format
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_quality(TColorGradingBuilder* tBuilder, TQualityLevel level)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->quality(static_cast<ColorGrading::QualityLevel>(level));
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_format(TColorGradingBuilder* tBuilder, TLutFormat format)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->format(static_cast<ColorGrading::LutFormat>(format));
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_dimensions(TColorGradingBuilder* tBuilder, uint8_t dim)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->dimensions(dim);
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_toneMapper(TColorGradingBuilder* tBuilder, TToneMapper* toneMapper)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            auto tm = reinterpret_cast<ToneMapper*>(toneMapper);
            builder->toneMapper(tm);
        }

        // Basic adjustments
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_exposure(TColorGradingBuilder* tBuilder, float exposure)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->exposure(exposure);
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_nightAdaptation(TColorGradingBuilder* tBuilder, float adaptation)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->nightAdaptation(adaptation);
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_whiteBalance(TColorGradingBuilder* tBuilder, float temperature, float tint)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->whiteBalance(temperature, tint);
        }

        // Color adjustments
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_contrast(TColorGradingBuilder* tBuilder, float contrast)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->contrast(contrast);
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_vibrance(TColorGradingBuilder* tBuilder, float vibrance)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->vibrance(vibrance);
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_saturation(TColorGradingBuilder* tBuilder, float saturation)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->saturation(saturation);
        }

        // Advanced controls
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_channelMixer(TColorGradingBuilder* tBuilder,
            float outRedR, float outRedG, float outRedB,
            float outGreenR, float outGreenG, float outGreenB,
            float outBlueR, float outBlueG, float outBlueB)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->channelMixer(
                math::float3{outRedR, outRedG, outRedB},
                math::float3{outGreenR, outGreenG, outGreenB},
                math::float3{outBlueR, outBlueG, outBlueB}
            );
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_shadowsMidtonesHighlights(TColorGradingBuilder* tBuilder,
            float shadowsR, float shadowsG, float shadowsB, float shadowsW,
            float midtonesR, float midtonesG, float midtonesB, float midtonesW,
            float highlightsR, float highlightsG, float highlightsB, float highlightsW,
            float rangesX, float rangesY, float rangesZ, float rangesW)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->shadowsMidtonesHighlights(
                math::float4{shadowsR, shadowsG, shadowsB, shadowsW},
                math::float4{midtonesR, midtonesG, midtonesB, midtonesW},
                math::float4{highlightsR, highlightsG, highlightsB, highlightsW},
                math::float4{rangesX, rangesY, rangesZ, rangesW}
            );
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_slopeOffsetPower(TColorGradingBuilder* tBuilder,
            float slopeR, float slopeG, float slopeB,
            float offsetR, float offsetG, float offsetB,
            float powerR, float powerG, float powerB)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->slopeOffsetPower(
                math::float3{slopeR, slopeG, slopeB},
                math::float3{offsetR, offsetG, offsetB},
                math::float3{powerR, powerG, powerB}
            );
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_curves(TColorGradingBuilder* tBuilder,
            float shadowGammaR, float shadowGammaG, float shadowGammaB,
            float midPointR, float midPointG, float midPointB,
            float highlightScaleR, float highlightScaleG, float highlightScaleB)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->curves(
                math::float3{shadowGammaR, shadowGammaG, shadowGammaB},
                math::float3{midPointR, midPointG, midPointB},
                math::float3{highlightScaleR, highlightScaleG, highlightScaleB}
            );
        }

        // Flags
        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_luminanceScaling(TColorGradingBuilder* tBuilder, bool enabled)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->luminanceScaling(enabled);
        }

        EMSCRIPTEN_KEEPALIVE void ColorGradingBuilder_gamutMapping(TColorGradingBuilder* tBuilder, bool enabled)
        {
            auto builder = reinterpret_cast<ColorGrading::Builder*>(tBuilder);
            builder->gamutMapping(enabled);
        }

        void View_setAntiAliasing(TView *tView, bool msaa, bool fxaa, bool taa)
        {
            auto view = reinterpret_cast<View *>(tView);
            View::MultiSampleAntiAliasingOptions multiSampleAntiAliasingOptions;
            multiSampleAntiAliasingOptions.enabled = msaa;
            multiSampleAntiAliasingOptions.sampleCount = 2;
            view->setMultiSampleAntiAliasingOptions(multiSampleAntiAliasingOptions);

            TemporalAntiAliasingOptions taaOpts;
            taaOpts.enabled = taa;

            view->setTemporalAntiAliasingOptions(taaOpts);
            view->setAntiAliasing(fxaa ? AntiAliasing::FXAA : AntiAliasing::NONE);
        }

        EMSCRIPTEN_KEEPALIVE void View_setLayerEnabled(TView *tView, int layer, bool enabled)
        {
            auto view = reinterpret_cast<View *>(tView);
            view->setLayerEnabled(layer, enabled);
        }

        EMSCRIPTEN_KEEPALIVE void View_setCamera(TView *tView, TCamera *tCamera)
        {
            auto view = reinterpret_cast<View *>(tView);
            auto *camera = reinterpret_cast<Camera *>(tCamera);
            view->setCamera(camera);
        }

        EMSCRIPTEN_KEEPALIVE TScene *View_getScene(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            return reinterpret_cast<TScene *>(view->getScene());
        }

        EMSCRIPTEN_KEEPALIVE TCamera *View_getCamera(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            return reinterpret_cast<TCamera *>(&(view->getCamera()));
        }

        EMSCRIPTEN_KEEPALIVE void View_setStencilBufferEnabled(TView *tView, bool enabled)
        {
            auto view = reinterpret_cast<View *>(tView);
            view->setStencilBufferEnabled(enabled);
        }

        EMSCRIPTEN_KEEPALIVE bool View_isStencilBufferEnabled(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            return view->isStencilBufferEnabled();
        }

        EMSCRIPTEN_KEEPALIVE void View_pick(TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback)
        {
            auto *view = reinterpret_cast<View *>(tView);
            view->pick(x, y, [=](filament::View::PickingQueryResult const &result)
                       { callback(requestId, utils::Entity::smuggle(result.renderable), result.depth, result.fragCoords.x, result.fragCoords.y, result.fragCoords.z); });
        }

        EMSCRIPTEN_KEEPALIVE void View_setDitheringEnabled(TView *tView, bool enabled)
        {
            auto *view = reinterpret_cast<View *>(tView);
            if (enabled)
            {
                view->setDithering(Dithering::TEMPORAL);
            }
            else
            {
                view->setDithering(Dithering::NONE);
            }
        }

        EMSCRIPTEN_KEEPALIVE bool View_isDitheringEnabled(TView *tView)
        {
            auto *view = reinterpret_cast<View *>(tView);
            return view->getDithering() == Dithering::TEMPORAL;
        }

        EMSCRIPTEN_KEEPALIVE void View_setRenderQuality(TView *tView, TQualityLevel qualityLevel)
        {
            auto view = reinterpret_cast<View *>(tView);
            RenderQuality rq;
            rq.hdrColorBuffer = (filament::QualityLevel)qualityLevel;
            switch (rq.hdrColorBuffer)
            {
            case filament::QualityLevel::LOW:
                TRACE("Render Quality: LOW");
                break;
            case filament::QualityLevel::MEDIUM:
                TRACE("Render Quality: MEDIUM");
                break;
            case filament::QualityLevel::HIGH:
                TRACE("Render Quality: HIGH");
                break;
            case filament::QualityLevel::ULTRA:
                TRACE("Render Quality: ULTRA");
                break;
            }

            view->setRenderQuality(rq);
        }

        EMSCRIPTEN_KEEPALIVE void View_setScene(TView *tView, TScene *tScene)
        {
            auto *view = reinterpret_cast<View *>(tView);
            auto *scene = reinterpret_cast<Scene *>(tScene);
            view->setScene(scene);
        }

        EMSCRIPTEN_KEEPALIVE void View_setFrontFaceWindingInverted(TView *tView, bool inverted)
        {
            auto *view = reinterpret_cast<View *>(tView);
            view->setFrontFaceWindingInverted(inverted);
        }
        EMSCRIPTEN_KEEPALIVE void View_setFogOptions(TView *tView, TFogOptions tFogOptions)
        {
            auto view = reinterpret_cast<View *>(tView);

            FogOptions fogOptions {
                .distance = tFogOptions.distance,
                .cutOffDistance = tFogOptions.cutOffDistance,
                .maximumOpacity = tFogOptions.maximumOpacity,
                .height = tFogOptions.height,
                .heightFalloff = tFogOptions.heightFalloff,
                .color = LinearColor(tFogOptions.linearColorR, tFogOptions.linearColorG, tFogOptions.linearColorB),
                .density = tFogOptions.density,
                .inScatteringStart = tFogOptions.inScatteringStart,
                .inScatteringSize = tFogOptions.inScatteringSize,
                .fogColorFromIbl = tFogOptions.fogColorFromIbl == 1,
                .skyColor = reinterpret_cast<Texture *>(tFogOptions.skyColor),
                .enabled = tFogOptions.enabled == 1
            };

            TRACE("Setting fog enabled to %d (tFogOptions.cutOffDistance %f)", fogOptions.enabled, tFogOptions.cutOffDistance);
            view->setFogOptions(fogOptions);
        }

        EMSCRIPTEN_KEEPALIVE TFogOptions View_getFogOptions(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            auto options = view->getFogOptions();

            TFogOptions tOptions;
            tOptions.distance = options.distance;
            tOptions.cutOffDistance = options.cutOffDistance;
            tOptions.maximumOpacity = options.maximumOpacity;
            tOptions.height = options.height;
            tOptions.heightFalloff = options.heightFalloff;
            tOptions.density = options.density;
            tOptions.inScatteringStart = options.inScatteringStart;
            tOptions.inScatteringSize = options.inScatteringSize;
            tOptions.fogColorFromIbl = options.fogColorFromIbl;
            tOptions.skyColor = reinterpret_cast<TTexture *>(options.skyColor);
            tOptions.linearColorR = options.color.r;
            tOptions.linearColorG = options.color.g;
            tOptions.linearColorB = options.color.b;
            tOptions.enabled = options.enabled;

            return tOptions;
        }

        EMSCRIPTEN_KEEPALIVE void View_setName(TView* tView, const char *name) {
            auto view = reinterpret_cast<View *>(tView);
            view->setName(name);
        }

        EMSCRIPTEN_KEEPALIVE const char *View_getName(TView* tView) {
            auto view = reinterpret_cast<View *>(tView);
            return view->getName();
        }

        EMSCRIPTEN_KEEPALIVE void View_setAmbientOcclusionOptions(TView *tView, TAmbientOcclusionOptions options)
        {
            auto view = reinterpret_cast<View *>(tView);
            AmbientOcclusionOptions aoOptions;

            aoOptions.aoType = static_cast<AmbientOcclusionOptions::AmbientOcclusionType>(options.aoType);
            aoOptions.radius = options.radius;
            aoOptions.power = options.power;
            aoOptions.bias = options.bias;
            aoOptions.resolution = options.resolution;
            aoOptions.intensity = options.intensity;
            aoOptions.bilateralThreshold = options.bilateralThreshold;
            aoOptions.quality = static_cast<QualityLevel>(options.quality);
            aoOptions.lowPassFilter = static_cast<QualityLevel>(options.lowPassFilter);
            aoOptions.upsampling = static_cast<QualityLevel>(options.upsampling);
            aoOptions.enabled = options.enabled;
            aoOptions.bentNormals = options.bentNormals;
            aoOptions.minHorizonAngleRad = options.minHorizonAngleRad;

            // Copy SSCT options
            aoOptions.ssct.lightConeRad = options.ssct.lightConeRad;
            aoOptions.ssct.shadowDistance = options.ssct.shadowDistance;
            aoOptions.ssct.contactDistanceMax = options.ssct.contactDistanceMax;
            aoOptions.ssct.intensity = options.ssct.intensity;
            aoOptions.ssct.lightDirection = filament::math::float3{options.ssct.lightDirectionX, options.ssct.lightDirectionY, options.ssct.lightDirectionZ};
            aoOptions.ssct.depthBias = options.ssct.depthBias;
            aoOptions.ssct.depthSlopeBias = options.ssct.depthSlopeBias;
            aoOptions.ssct.sampleCount = options.ssct.sampleCount;
            aoOptions.ssct.rayCount = options.ssct.rayCount;
            aoOptions.ssct.enabled = options.ssct.enabled;

            // Copy GTAO options
            aoOptions.gtao.sampleSliceCount = options.gtao.sampleSliceCount;
            aoOptions.gtao.sampleStepsPerSlice = options.gtao.sampleStepsPerSlice;
            aoOptions.gtao.thicknessHeuristic = options.gtao.thicknessHeuristic;
            aoOptions.gtao.useVisibilityBitmasks = options.gtao.useVisibilityBitmasks;
            aoOptions.gtao.constThickness = options.gtao.constThickness;
            aoOptions.gtao.linearThickness = options.gtao.linearThickness;

            view->setAmbientOcclusionOptions(aoOptions);
        }

        EMSCRIPTEN_KEEPALIVE TAmbientOcclusionOptions View_getAmbientOcclusionOptions(TView *tView)
        {
            auto view = reinterpret_cast<View *>(tView);
            auto options = view->getAmbientOcclusionOptions();

            TAmbientOcclusionOptions tOptions;
            tOptions.aoType = static_cast<TAmbientOcclusionType>(options.aoType);
            tOptions.radius = options.radius;
            tOptions.power = options.power;
            tOptions.bias = options.bias;
            tOptions.resolution = options.resolution;
            tOptions.intensity = options.intensity;
            tOptions.bilateralThreshold = options.bilateralThreshold;
            tOptions.quality = static_cast<TQualityLevel>(options.quality);
            tOptions.lowPassFilter = static_cast<TQualityLevel>(options.lowPassFilter);
            tOptions.upsampling = static_cast<TQualityLevel>(options.upsampling);
            tOptions.enabled = options.enabled;
            tOptions.bentNormals = options.bentNormals;
            tOptions.minHorizonAngleRad = options.minHorizonAngleRad;

            // Copy SSCT options
            tOptions.ssct.lightConeRad = options.ssct.lightConeRad;
            tOptions.ssct.shadowDistance = options.ssct.shadowDistance;
            tOptions.ssct.contactDistanceMax = options.ssct.contactDistanceMax;
            tOptions.ssct.intensity = options.ssct.intensity;
            tOptions.ssct.lightDirectionX = options.ssct.lightDirection.x;
            tOptions.ssct.lightDirectionY = options.ssct.lightDirection.y;
            tOptions.ssct.lightDirectionZ = options.ssct.lightDirection.z;
            tOptions.ssct.depthBias = options.ssct.depthBias;
            tOptions.ssct.depthSlopeBias = options.ssct.depthSlopeBias;
            tOptions.ssct.sampleCount = options.ssct.sampleCount;
            tOptions.ssct.rayCount = options.ssct.rayCount;
            tOptions.ssct.enabled = options.ssct.enabled;

            // Copy GTAO options
            tOptions.gtao.sampleSliceCount = options.gtao.sampleSliceCount;
            tOptions.gtao.sampleStepsPerSlice = options.gtao.sampleStepsPerSlice;
            tOptions.gtao.thicknessHeuristic = options.gtao.thicknessHeuristic;
            tOptions.gtao.useVisibilityBitmasks = options.gtao.useVisibilityBitmasks;
            tOptions.gtao.constThickness = options.gtao.constThickness;
            tOptions.gtao.linearThickness = options.gtao.linearThickness;

            return tOptions;
        }

        EMSCRIPTEN_KEEPALIVE void View_setTransparentPickingEnabled(TView* tView, bool enabled) {
            auto view = reinterpret_cast<View *>(tView);
            view->setTransparentPickingEnabled(enabled);
        }

        EMSCRIPTEN_KEEPALIVE bool View_isTransparentPickingEnabled(TView* tView) {
            auto view = reinterpret_cast<View *>(tView);
            return view->isTransparentPickingEnabled();
        }

#ifdef __cplusplus
    }
}
#endif
