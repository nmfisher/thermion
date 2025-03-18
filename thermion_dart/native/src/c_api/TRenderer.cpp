#ifdef _WIN32
#include "ThermionWin32.h"
#endif

#include "Log.hpp"

#include <thread>
#include <functional>

#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/Renderer.h>
#include <filament/SwapChain.h>
#include <filament/Texture.h>
#include <filament/Viewport.h>
#include <filament/View.h>
#include <filament/math/mat4.h>

#include "c_api/TTexture.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {

#endif

#include "c_api/ThermionDartApi.h"

EMSCRIPTEN_KEEPALIVE void Renderer_setClearOptions(TRenderer *tRenderer, double clearR, double clearG, double clearB, double clearA, uint8_t clearStencil, bool clear, bool discard) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    filament::Renderer::ClearOptions clearOpts;
    clearOpts.clearColor = filament::math::float4 { static_cast<float>(clearR), static_cast<float>(clearG), static_cast<float>(clearB),static_cast<float>(clearA)};
    clearOpts.clear = clear;
    clearOpts.discard = discard;
    clearOpts.clearStencil = clearStencil;
    renderer->setClearOptions(clearOpts);
}

EMSCRIPTEN_KEEPALIVE bool Renderer_beginFrame(TRenderer *tRenderer, TSwapChain *tSwapChain, uint64_t frameTimeInNanos) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *swapChain = reinterpret_cast<filament::SwapChain *>(tSwapChain);
    return renderer->beginFrame(swapChain, frameTimeInNanos);
}

EMSCRIPTEN_KEEPALIVE void Renderer_endFrame(TRenderer *tRenderer) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    renderer->endFrame();
}

EMSCRIPTEN_KEEPALIVE void Renderer_render(TRenderer *tRenderer, TView *tView) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *view = reinterpret_cast<filament::View *>(tView);
    renderer->render(view);
}

EMSCRIPTEN_KEEPALIVE void Renderer_renderStandaloneView(TRenderer *tRenderer, TView *tView) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *view = reinterpret_cast<filament::View *>(tView);
    renderer->renderStandaloneView(view);
}

EMSCRIPTEN_KEEPALIVE void Renderer_setFrameRateOptions(
    TRenderer *tRenderer, 
    float headRoomRatio,
    float scaleRate,
    uint8_t history, 
    uint8_t interval 
) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    filament::Renderer::FrameRateOptions fro;
    fro.headRoomRatio = headRoomRatio;
    fro.scaleRate = scaleRate;
    fro.interval = interval;
    fro.interval = interval;
    renderer->setFrameRateOptions(fro);
}

class CaptureCallbackHandler : public filament::backend::CallbackHandler
{
  void post(void *user, Callback callback)
  {
    callback(user);
    delete this;
  }
};


EMSCRIPTEN_KEEPALIVE void Renderer_readPixels(
    TRenderer *tRenderer,
    TView *tView,
    TRenderTarget *tRenderTarget,
    TPixelDataFormat tPixelBufferFormat,
    TPixelDataType tPixelDataType,
    uint8_t *out) {
    
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *renderTarget = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
    auto *view = reinterpret_cast<filament::View *>(tView);

    filament::Viewport const &vp = view->getViewport();

    size_t pixelBufferSize = vp.width * vp.height * 4;

    filament::backend::PixelDataFormat pixelBufferFormat = static_cast<filament::backend::PixelDataFormat>(tPixelBufferFormat);
    filament::backend::PixelDataType pixelDataType = static_cast<filament::backend::PixelDataType>(tPixelDataType);

    auto *dispatcher = new CaptureCallbackHandler();
    auto callback = [](void *buf, size_t size, void *data)
    {
      
    };


    auto pbd = filament::Texture::PixelBufferDescriptor(
        out, pixelBufferSize,
        pixelBufferFormat,
        pixelDataType,
        dispatcher,
        callback,
        out
    );

    if(renderTarget) {
        renderer->readPixels(renderTarget, 0, 0, vp.width, vp.height, std::move(pbd));
    } else {
        renderer->readPixels(0, 0, vp.width, vp.height, std::move(pbd));
    }

}


#ifdef __cplusplus
    }
}
#endif
