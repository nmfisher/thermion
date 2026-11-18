#include "rendering/EngineApiLock.hpp"
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
#include "c_api/TRenderManager.h"

EMSCRIPTEN_KEEPALIVE TRenderManager *RenderManager_create(TEngine *tEngine, TRenderer *tRenderer) {
    THERMION_ENGINE_API_GUARD;
    auto engine = reinterpret_cast<filament::Engine *>(tEngine);
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *renderManager = new RenderManager(engine, renderer);
    return reinterpret_cast<TRenderManager *>(renderManager);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_destroy(TRenderManager *tRenderer) {
    THERMION_ENGINE_API_GUARD;
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    delete renderManager;
}

EMSCRIPTEN_KEEPALIVE void RenderManager_addAnimationManager(TRenderManager *tRenderer, TAnimationManager *tAnimationManager) {
    THERMION_ENGINE_API_GUARD;
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    auto *animationManager = reinterpret_cast<thermion::AnimationManager *>(tAnimationManager);
    renderManager->addAnimationManager(animationManager);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_removeAnimationManager(TRenderManager *tRenderer, TAnimationManager *tAnimationManager) {
    THERMION_ENGINE_API_GUARD;
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    auto *animationManager = reinterpret_cast<thermion::AnimationManager *>(tAnimationManager);
    renderManager->removeAnimationManager(animationManager);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_render(TRenderManager *tRenderer, uint64_t frameTimeInNanos) {
    THERMION_ENGINE_API_GUARD;
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    renderManager->render(frameTimeInNanos);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_setTargetFps(TRenderManager *tRenderer, int fps) {
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    renderManager->setTargetFps(fps);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_setPaused(TRenderManager *tRenderer, bool paused) {
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    renderManager->setPaused(paused);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_setRenderable(TRenderManager *tRenderer, TSwapChain *tSwapChain, TView **tViews, uint8_t numViews) {
    THERMION_ENGINE_API_GUARD;
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    auto *swapChain = reinterpret_cast<filament::SwapChain *>(tSwapChain);
    auto *views = reinterpret_cast<View **>(tViews);
    renderManager->setRenderable(swapChain, views, numViews);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_removeSwapChain(TRenderManager *tRenderer, TSwapChain *tSwapChain) {
    THERMION_ENGINE_API_GUARD;
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderer);
    auto *swapChain = reinterpret_cast<filament::SwapChain *>(tSwapChain);
    renderManager->removeSwapChain(swapChain);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_setMaterialOverride(TRenderManager *tRenderManager, TView *tView, TMaterialInstance *tMaterialInstance) {
    THERMION_ENGINE_API_GUARD;
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderManager);
    auto *view = reinterpret_cast<filament::View *>(tView);
    auto *materialInstance = reinterpret_cast<filament::MaterialInstance *>(tMaterialInstance);
    renderManager->setMaterialOverride(view, materialInstance);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_renderView(TRenderManager *tRenderManager, TView *tView, bool standalone) {
    THERMION_ENGINE_API_GUARD;
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderManager);
    auto *view = reinterpret_cast<filament::View *>(tView);
    renderManager->renderView(view, standalone);
}

EMSCRIPTEN_KEEPALIVE void RenderManager_capture(
    TRenderManager *tRenderManager,
    TSwapChain *tSwapChain,
    uint64_t frameTimeInNanos,
    bool render,
    const TCaptureViewRequest *tRequests,
    uint32_t viewCount,
    void (*onComplete)(TCaptureResult *)) {
    THERMION_ENGINE_API_GUARD;
    if (!onComplete) {
        return;
    }
    auto *renderManager = reinterpret_cast<RenderManager *>(tRenderManager);
    auto *swapChain = reinterpret_cast<filament::SwapChain *>(tSwapChain);
    std::vector<RenderManager::CaptureViewRequest> requests;
    if (tRequests && viewCount > 0) {
        requests.reserve(viewCount);
        for (uint32_t i = 0; i < viewCount; ++i) {
            requests.push_back(RenderManager::CaptureViewRequest{
                reinterpret_cast<filament::View *>(tRequests[i].view),
                reinterpret_cast<filament::RenderTarget *>(tRequests[i].renderTarget),
                tRequests[i].width,
                tRequests[i].height,
                static_cast<filament::backend::PixelDataFormat>(tRequests[i].format),
                static_cast<filament::backend::PixelDataType>(tRequests[i].type),
            });
        }
    }
    auto dispatch = [onComplete](std::unique_ptr<RenderManager::CaptureResult> result) {
        auto *raw = reinterpret_cast<TCaptureResult *>(result.release());
        ::thermion::deferDartCallback([onComplete, raw]() {
            onComplete(raw);
        });
    };
    if (!renderManager || !swapChain || requests.empty() ||
        !renderManager->capture(swapChain, frameTimeInNanos, render, requests, dispatch)) {
        dispatch(nullptr);
    }
}

EMSCRIPTEN_KEEPALIVE uint8_t *CaptureResult_getPixels(TCaptureResult *tCaptureResult, uint32_t index) {
    auto *result = reinterpret_cast<RenderManager::CaptureResult *>(tCaptureResult);
    if (!result || index >= result->buffers.size() || result->buffers[index].empty()) {
        return nullptr;
    }
    return result->buffers[index].data();
}

EMSCRIPTEN_KEEPALIVE uint32_t CaptureResult_getByteLength(TCaptureResult *tCaptureResult, uint32_t index) {
    auto *result = reinterpret_cast<RenderManager::CaptureResult *>(tCaptureResult);
    if (!result || index >= result->buffers.size()) {
        return 0;
    }
    return static_cast<uint32_t>(result->buffers[index].size());
}

EMSCRIPTEN_KEEPALIVE void CaptureResult_destroy(TCaptureResult *tCaptureResult) {
    auto *result = reinterpret_cast<RenderManager::CaptureResult *>(tCaptureResult);
    delete result;
}

}
