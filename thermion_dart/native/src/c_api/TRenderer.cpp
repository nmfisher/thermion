#include <cstring>
#include "ReadPixels.hpp"
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
#include <math/mat4.h>

#include "c_api/TTexture.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {

#endif

#include "c_api/TRenderer.h"

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

EMSCRIPTEN_KEEPALIVE void Renderer_readPixels(
    TRenderer *renderer,
    uint32_t width, uint32_t height, uint32_t x, uint32_t y,
    TRenderTarget *target, TPixelDataFormat format, TPixelDataType type,
    size_t length, void (*onComplete)(uint8_t*)) {
    Renderer_readPixelsOwned(renderer, width, height, x, y, target, format, type,
        length, onComplete);
}

EMSCRIPTEN_KEEPALIVE void Renderer_copyPixelsAndRelease(uint8_t *pixels, uint8_t *out, size_t length) {
    // The only write into Dart storage occurs synchronously in this FFI call.
    std::memcpy(out, pixels, length);
    delete[] pixels;
}

} // extern "C"

class PixelReadback : public filament::backend::CallbackHandler {
public:
    explicit PixelReadback(size_t length, std::function<void(uint8_t*)> completion)
        : pixels(new uint8_t[length]), onComplete(std::move(completion)) {}
    uint8_t *pixels;
    std::function<void(uint8_t*)> onComplete;

    void post(void *user, Callback callback) override {
        callback(user);
        delete this;
    }
};

void Renderer_readPixelsOwned(
    TRenderer *tRenderer,
    uint32_t width, uint32_t height, uint32_t x, uint32_t y,
    TRenderTarget *tRenderTarget, TPixelDataFormat format, TPixelDataType type,
    size_t length, std::function<void(uint8_t*)> onComplete) {
    auto *renderer = reinterpret_cast<filament::Renderer *>(tRenderer);
    auto *target = reinterpret_cast<filament::RenderTarget *>(tRenderTarget);
    auto *readback = new PixelReadback(length, std::move(onComplete));
    filament::Texture::PixelBufferDescriptor pbd(
        readback->pixels, length,
        static_cast<filament::backend::PixelDataFormat>(format),
        static_cast<filament::backend::PixelDataType>(type),
        1, 0, 0, 0, // tightly packed rows, including odd-width RGB captures
        readback,
        [](void*, size_t, void *user) {
            auto *readback = static_cast<PixelReadback*>(user);
            // The consumer now owns pixels; the handler releases only its context.
            readback->onComplete(readback->pixels);
        }, readback);
    if (target) {
        renderer->readPixels(target, x, y, width, height, std::move(pbd));
    } else {
        renderer->readPixels(x, y, width, height, std::move(pbd));
    }
}

#ifdef __cplusplus
} // namespace thermion
#endif
