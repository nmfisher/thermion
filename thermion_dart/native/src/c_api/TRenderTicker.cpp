#ifdef _WIN32
#include "ThermionWin32.h"
#endif

#include <thread>
#include <functional>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#endif

#include "filament/LightManager.h"
#include "Log.hpp"

using namespace thermion;

extern "C"
{
#include "c_api/TRenderTicker.hpp"

EMSCRIPTEN_KEEPALIVE TRenderTicker *RenderTicker_create(TRenderer *tRenderer) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *renderTicker = new RenderTicker(renderer);
    return reinterpret_cast<TRenderTicker *>(renderTicker);
}

EMSCRIPTEN_KEEPALIVE void RenderTicker_destroy(TRenderTicker *tRenderTicker,) {
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
    auto *renderTicker = reinterpret_cast<RenderTicker *>
    renderTicker->render(frameTimeInNanos);
}

EMSCRIPTEN_KEEPALIVE void RenderTicker_setRenderable(TRenderTicker *tRenderTicker, TSwapChain *swapChain, TView **views, uint8_t numViews) {
    auto *renderTicker = reinterpret_cast<RenderTicker *>
    renderTicker->setRenderable(swapChain, views, numViews);
}

}
