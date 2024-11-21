#include <filament/View.h>
#include <filament/Viewport.h>
#include <filament/Engine.h>
#include <filament/ToneMapper.h>
#include <filament/ColorGrading.h>
#include <filament/Camera.h>

#include "c_api/ThermionDartApi.h"
#include "c_api/TView.h"
#include "Log.hpp"

#ifdef __cplusplus
namespace thermion {
extern "C"
{
using namespace filament;

#endif

    EMSCRIPTEN_KEEPALIVE TViewport View_getViewport(TView *tView)
    {
        auto view = reinterpret_cast<View *>(tView);
        auto & vp = view->getViewport();
        TViewport tvp;
        tvp.left = vp.left;
        tvp.bottom = vp.bottom;
        tvp.width = vp.width;
        tvp.height = vp.height;
        return tvp;
    }

    EMSCRIPTEN_KEEPALIVE void View_updateViewport(TView *tView, uint32_t width, uint32_t height)
    {
        auto view = reinterpret_cast<View *>(tView);
        view->setViewport({0, 0, width, height});
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

    EMSCRIPTEN_KEEPALIVE void View_setBloom(TView *tView, float strength)
    {
        auto view = reinterpret_cast<View *>(tView);
#ifndef __EMSCRIPTEN__
        decltype(view->getBloomOptions()) opts;
        opts.enabled = true;
        opts.strength = strength;
        view->setBloomOptions(opts);
#endif
    }

    EMSCRIPTEN_KEEPALIVE void View_setToneMapping(TView *tView, TEngine *tEngine, ToneMapping toneMapping)
    {
        auto view = reinterpret_cast<View *>(tView);
        auto engine = reinterpret_cast<Engine *>(tEngine);

        ToneMapper *tm;
        switch (toneMapping)
        {
        case ToneMapping::ACES:
            Log("Setting tone mapping to ACES");
            tm = new ACESToneMapper();
            break;
        case ToneMapping::LINEAR:
            Log("Setting tone mapping to Linear");
            tm = new LinearToneMapper();
            break;
        case ToneMapping::FILMIC:
            Log("Setting tone mapping to Filmic");
            tm = new FilmicToneMapper();
            break;
        default:
            Log("ERROR: Unsupported tone mapping");
            return;
        }
        auto newColorGrading = ColorGrading::Builder().toneMapper(tm).build(*engine);
        auto oldColorGrading = view->getColorGrading();
        view->setColorGrading(newColorGrading);

        if (oldColorGrading)
        {
            engine->destroy(oldColorGrading);
        }
        delete tm;
    }

    void View_setAntiAliasing(TView *tView, bool msaa, bool fxaa, bool taa)
    {
        auto view = reinterpret_cast<View *>(tView);
        View::MultiSampleAntiAliasingOptions multiSampleAntiAliasingOptions;
        multiSampleAntiAliasingOptions.enabled = msaa;

        view->setMultiSampleAntiAliasingOptions(multiSampleAntiAliasingOptions);
        TemporalAntiAliasingOptions taaOpts;
        taaOpts.enabled = taa;
        view->setTemporalAntiAliasingOptions(taaOpts);
        view->setAntiAliasing(fxaa ? AntiAliasing::FXAA : AntiAliasing::NONE);
    }

    EMSCRIPTEN_KEEPALIVE void View_setLayerEnabled(TView* tView, int layer, bool enabled) {
        auto view = reinterpret_cast<View *>(tView);
        view->setLayerEnabled(layer, enabled);
    }

    EMSCRIPTEN_KEEPALIVE void View_setCamera(TView *tView, TCamera *tCamera) { 
        auto view = reinterpret_cast<View *>(tView);
        auto *camera = reinterpret_cast<Camera *>(tCamera);
        view->setCamera(camera);
    }

    EMSCRIPTEN_KEEPALIVE TScene* View_getScene(TView* tView) {
        auto view = reinterpret_cast<View *>(tView);
        return reinterpret_cast<TScene*>(view->getScene());
    }

    EMSCRIPTEN_KEEPALIVE TCamera* View_getCamera(TView *tView) {
        auto view = reinterpret_cast<View *>(tView);
        return reinterpret_cast<TCamera*>(&(view->getCamera()));
    }

    EMSCRIPTEN_KEEPALIVE void View_setStencilBufferEnabled(TView *tView, bool enabled) {
        auto view = reinterpret_cast<View *>(tView);
        view->setStencilBufferEnabled(enabled);
    }

    EMSCRIPTEN_KEEPALIVE bool View_isStencilBufferEnabled(TView *tView) {
        auto view = reinterpret_cast<View *>(tView);
        return view->isStencilBufferEnabled();
    }

        

    EMSCRIPTEN_KEEPALIVE void View_pick(TView *tView, uint32_t requestId, uint32_t x, uint32_t y, PickCallback callback)
    {
        auto *view = reinterpret_cast<View *>(tView);
        view->pick(x, y, [=](filament::View::PickingQueryResult const &result) {       
            callback(requestId, utils::Entity::smuggle(result.renderable), result.depth, result.fragCoords.x, result.fragCoords.y, result.fragCoords.z);
        });
    }

#ifdef __cplusplus
}
}
#endif
