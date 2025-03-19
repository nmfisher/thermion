#ifdef _WIN32
#include "ThermionWin32.h"
#endif
#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

#include <thread>
#include <functional>

#include <filament/LightManager.h>

#include "Log.hpp"
#include "RenderTicker.hpp"

using namespace thermion;

extern "C"
{
#include "c_api/TRenderTicker.h"

EMSCRIPTEN_KEEPALIVE TRenderTicker *RenderTicker_create(TRenderer *tRenderer) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *renderTicker = new RenderTicker(renderer);
    return reinterpret_cast<TRenderTicker *>(renderTicker);
}

EMSCRIPTEN_KEEPALIVE void RenderTicker_destroy(TRenderTicker *tRenderTicker) {
    auto *renderTicker = reinterpret_cast<RenderTicker *>(tRenderTicker);
    delete renderTicker;
}

EMSCRIPTEN_KEEPALIVE void RenderTicker_addAnimationManager(TRenderTicker *tRenderTicker, TAnimationManager *tAnimationManager) {
    auto *renderTicker = reinterpret_cast<RenderTicker *>(tRenderTicker);
    auto *animationManager = reinterpret_cast<thermion::AnimationManager *>(tAnimationManager);
    renderTicker->addAnimationManager(animationManager);
}

EMSCRIPTEN_KEEPALIVE void RenderTicker_removeAnimationManager(TRenderTicker *tRenderTicker, TAnimationManager *tAnimationManager) {
    auto *renderTicker = reinterpret_cast<RenderTicker *>(tRenderTicker);
    auto *animationManager = reinterpret_cast<thermion::AnimationManager *>(tAnimationManager);
    renderTicker->removeAnimationManager(animationManager);
}

EMSCRIPTEN_KEEPALIVE void RenderTicker_render(TRenderTicker *tRenderTicker, uint64_t frameTimeInNanos) {
    auto *renderTicker = reinterpret_cast<RenderTicker *>(tRenderTicker);
    renderTicker->render(frameTimeInNanos);
}

EMSCRIPTEN_KEEPALIVE void RenderTicker_setRenderable(TRenderTicker *tRenderTicker, TSwapChain *tSwapChain, TView **tViews, uint8_t numViews) {
    auto *renderTicker = reinterpret_cast<RenderTicker *>(tRenderTicker);
    auto *swapChain = reinterpret_cast<filament::SwapChain *>(tSwapChain);
    auto *views = reinterpret_cast<View **>(tViews);
    renderTicker->setRenderable(swapChain, views, numViews);
}

}
