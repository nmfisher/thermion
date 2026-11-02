#pragma once

#include <cstdint>

namespace thermion::detail
{
    // Filament 1.77.2 queues its backend tick before checking frame admission.
    // An admission rejection flushes that poll; in the single-threaded WebGL
    // backend the flush also executes it. Retry this swapchain once to use the
    // refreshed completion state, without an additional Engine::execute().
    // Genuine GPU backpressure still rejects the retry. Each attempt advances
    // Filament's own frame bookkeeping; animation/plugin updates stay outside.
    template<typename Renderer, typename SwapChain>
    bool beginFrameWithRetry(Renderer& renderer,
            SwapChain* swapChain, uint64_t frameTimeInNanos)
    {
        if (renderer.beginFrame(swapChain, frameTimeInNanos)) return true;
        return renderer.beginFrame(swapChain, frameTimeInNanos);
    }
}
