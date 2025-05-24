#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

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

        EMSCRIPTEN_KEEPALIVE void View_setSoftShadowOptions(TView *tView, float penumbraScale, float penumbraRatioScale)
        {
            auto view = reinterpret_cast<View *>(tView);
            SoftShadowOptions opts;
            opts.penumbraRatioScale = penumbraRatioScale;
            opts.penumbraScale = penumbraScale;
            view->setSoftShadowOptions(opts);
        }

        EMSCRIPTEN_KEEPALIVE void View_setBloom(TView *tView, bool enabled, float strength)
        {
            auto view = reinterpret_cast<View *>(tView);
#ifndef __EMSCRIPTEN__
            decltype(view->getBloomOptions()) opts;
            opts.enabled = enabled;
            opts.strength = strength;
            TRACE("Setting bloom options {.enabled = %d, strength = %f}", enabled, strength);
            view->setBloomOptions(opts);
#endif
        }

        EMSCRIPTEN_KEEPALIVE void View_setColorGrading(TView *tView, TColorGrading *tColorGrading)
        {
            auto *view = reinterpret_cast<View *>(tView);
            auto *colorGrading = reinterpret_cast<ColorGrading *>(tColorGrading);
            view->setColorGrading(colorGrading);
        }

        EMSCRIPTEN_KEEPALIVE TColorGrading *ColorGrading_create(TEngine *tEngine, TToneMapping tToneMapping)
        {
            auto engine = reinterpret_cast<Engine *>(tEngine);

            ToneMapper *tm;
            switch (tToneMapping)
            {
            case TToneMapping::ACES:
                TRACE("Setting tone mapping to ACES");
                tm = new ACESToneMapper();
                break;
            case TToneMapping::LINEAR:
                TRACE("Setting tone mapping to Linear");
                tm = new LinearToneMapper();
                break;
            case TToneMapping::FILMIC:
                TRACE("Setting tone mapping to Filmic");
                tm = new FilmicToneMapper();
                break;
            default:
                TRACE("ERROR: Unsupported tone mapping");
                return nullptr;
            }
            auto colorGrading = ColorGrading::Builder().toneMapper(tm).build(*engine);

            delete tm;
            return reinterpret_cast<TColorGrading *>(colorGrading);
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

        EMSCRIPTEN_KEEPALIVE void View_setFogOptions(TView *tView, TFogOptions *tFogOptions)
        {
            auto view = reinterpret_cast<View *>(tView);
            FogOptions fogOptions {
                .distance = tFogOptions->distance,
                .cutOffDistance = tFogOptions->cutOffDistance,
                .maximumOpacity = tFogOptions->maximumOpacity,
                .height = tFogOptions->height,
                .heightFalloff = tFogOptions->heightFalloff,
                .color = LinearColor(tFogOptions->linearColor.x, tFogOptions->linearColor.y, tFogOptions->linearColor.z),
                .density = tFogOptions->density,
                .inScatteringStart = tFogOptions->inScatteringStart,
                .inScatteringSize = tFogOptions->inScatteringSize,
                .fogColorFromIbl = tFogOptions->fogColorFromIbl,
                .skyColor = reinterpret_cast<Texture *>(tFogOptions->skyColor),
                .enabled = tFogOptions->enabled
            };
            
        
            TRACE("Setting fog enabled to %d (tFogOptions->cutOffDistance %f)", fogOptions.enabled, tFogOptions->cutOffDistance);
            view->setFogOptions(fogOptions);
        }

#ifdef __cplusplus
    }
}
#endif
