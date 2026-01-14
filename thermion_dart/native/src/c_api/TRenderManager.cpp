#ifdef _WIN32
#include "ThermionWin32.h"
#endif

#include <thread>
#include <functional>

#include <filament/LightManager.h>

#include "Log.hpp"
#include "rendering/RenderManager.hpp"

using namespace thermion;

extern "C"
{
#include "c_api/TRenderer.h"

EMSCRIPTEN_KEEPALIVE TRenderManager *RenderManager_create(TEngine *tEngine, TRenderer *tRenderer) {
    auto engine = reinterpret_cast<filament::Engine *>(tEngine);
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *renderManager = new RenderManager(engine, renderer);
    return reinterpret_cast<TRenderManager *>(renderManager);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_destroy(TRenderManager *tRenderer) {
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    delete renderManager;
}

EMSCRIPTEN_KEEPALIVE void RenderManager_addAnimationManager(TRenderManager *tRenderer, TAnimationManager *tAnimationManager) {
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    auto *animationManager = reinterpret_cast<thermion::AnimationManager *>(tAnimationManager);
    renderManager->addAnimationManager(animationManager);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_removeAnimationManager(TRenderManager *tRenderer, TAnimationManager *tAnimationManager) {
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    auto *animationManager = reinterpret_cast<thermion::AnimationManager *>(tAnimationManager);
    renderManager->removeAnimationManager(animationManager);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_render(TRenderManager *tRenderer, uint64_t frameTimeInNanos) {
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    renderManager->render(frameTimeInNanos);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_setRenderable(TRenderManager *tRenderer, TSwapChain *tSwapChain, TView **tViews, uint8_t numViews) {
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    auto *swapChain = reinterpret_cast<filament::SwapChain *>(tSwapChain);
    auto *views = reinterpret_cast<View **>(tViews);
    renderManager->setRenderable(swapChain, views, numViews);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_removeSwapChain(TRenderManager *tRenderer, TSwapChain *tSwapChain) {
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    auto *swapChain = reinterpret_cast<filament::SwapChain *>(tSwapChain);
    renderManager->removeSwapChain(swapChain);
}

}
