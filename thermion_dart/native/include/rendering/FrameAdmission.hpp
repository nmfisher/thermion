#pragma once

#include <cstdint>

namespace thermion::detail
{
    // The manually executed WebGL backend queues a fence poll in beginFrame(),
    // but frame admission can still see the previous cached completion state.
    // Drain that poll after rejection and retry this swapchain once. Genuine
    // GPU backpressure still rejects the second attempt; never force a frame.
    // Keep animation/plugin updates outside this operation.
    template<typename Engine, typename Renderer, typename SwapChain>
    bool beginFrameWithRetry(Engine& engine, Renderer& renderer,
            SwapChain* swapChain, uint64_t frameTimeInNanos)
    {
        if (renderer.beginFrame(swapChain, frameTimeInNanos)) return true;
        engine.execute();
        return renderer.beginFrame(swapChain, frameTimeInNanos);
    }
}
