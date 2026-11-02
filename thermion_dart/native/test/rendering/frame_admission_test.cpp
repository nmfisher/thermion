#include "rendering/FrameAdmission.hpp"

#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <utility>
#include <vector>

static void require(bool condition, const char* message)
{
    if (!condition) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        std::abort();
    }
}

struct SwapChain {
    bool gpuComplete;
    bool cachedComplete;
};

struct Engine {
    std::vector<SwapChain*> pendingPolls;
    unsigned executions = 0;
    void execute() {
        ++executions;
        for (auto* swapChain : pendingPolls) {
            swapChain->cachedComplete = swapChain->gpuComplete;
        }
        pendingPolls.clear();
    }
};

struct Renderer {
    Engine& engine;
    std::vector<std::pair<SwapChain*, uint64_t>> attempts;
    bool beginFrame(SwapChain* swapChain, uint64_t timestamp) {
        attempts.emplace_back(swapChain, timestamp);
        // Match Filament's ordering: queue the poll, read cached completion,
        // then flush/execute the poll if the frame was rejected.
        engine.pendingPolls.push_back(swapChain);
        const bool accepted = swapChain->cachedComplete;
        if (!accepted) engine.execute();
        return accepted;
    }
};

int main()
{
    using thermion::detail::beginFrameWithRetry;
    constexpr uint64_t timestamp = 123456789;
    {
        SwapChain ready{true, true};
        Engine engine;
        Renderer renderer{engine};
        require(beginFrameWithRetry(renderer, &ready, timestamp),
                "ready frame was rejected");
        require(renderer.attempts.size() == 1 && engine.executions == 0,
                "ready frame retried or needlessly drained the backend");
    }
    {
        SwapChain stale{true, false};
        Engine engine;
        Renderer renderer{engine};
        engine.execute(); // No fresh poll has been queued yet.
        require(!stale.cachedComplete, "an empty drain invented a fence poll");
        require(!renderer.beginFrame(&stale, timestamp),
                "start-of-tick drain unexpectedly refreshed a future poll");
        require(stale.cachedComplete,
                "rejection did not execute the newly queued completion poll");
    }
    {
        SwapChain stale{true, false};
        Engine engine;
        Renderer renderer{engine};
        require(beginFrameWithRetry(renderer, &stale, timestamp),
                "completed frame was dropped because its cache was stale");
        require(renderer.attempts.size() == 2 && engine.executions == 1,
                "retry added a redundant drain after Filament already flushed");
        for (const auto& attempt : renderer.attempts) {
            require(attempt.first == &stale && attempt.second == timestamp,
                    "retry changed swapchain or animation timestamp");
        }
    }
    {
        SwapChain busy{false, false};
        Engine engine;
        Renderer renderer{engine};
        require(!beginFrameWithRetry(renderer, &busy, timestamp),
                "busy GPU was forced to accept a frame");
        require(renderer.attempts.size() == 2 && engine.executions == 2,
                "busy GPU exceeded two admission attempts/rejection flushes");
    }
    {
        SwapChain ready{true, true}, stale{true, false};
        Engine engine;
        Renderer renderer{engine};
        for (auto* swapChain : std::array{&ready, &stale}) {
            require(beginFrameWithRetry(renderer, swapChain, timestamp),
                    "partial rejection was hidden by another ready swapchain");
        }
        require(renderer.attempts.size() == 3 && engine.executions == 1,
                "retry resubmitted an already accepted swapchain");
        require(renderer.attempts[0].first == &ready &&
                renderer.attempts[1].first == &stale &&
                renderer.attempts[2].first == &stale,
                "retry did not stay local to the rejected swapchain");
    }
    std::puts("PASS: bounded WebGL frame admission preserves GPU backpressure");
}
