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

struct Renderer {
    std::vector<std::pair<SwapChain*, uint64_t>> attempts;
    bool beginFrame(SwapChain* swapChain, uint64_t timestamp) {
        attempts.emplace_back(swapChain, timestamp);
        return swapChain->cachedComplete;
    }
};

struct Engine {
    std::vector<SwapChain*> swapChains;
    unsigned executions = 0;
    void execute() {
        ++executions;
        for (auto* swapChain : swapChains) {
            swapChain->cachedComplete = swapChain->gpuComplete;
        }
    }
};

int main()
{
    using thermion::detail::beginFrameWithRetry;
    constexpr uint64_t timestamp = 123456789;
    {
        SwapChain ready{true, true};
        Engine engine{{&ready}};
        Renderer renderer;
        require(beginFrameWithRetry(engine, renderer, &ready, timestamp),
                "ready frame was rejected");
        require(renderer.attempts.size() == 1 && engine.executions == 0,
                "ready frame retried or needlessly drained the backend");
    }
    {
        SwapChain stale{true, false};
        Engine engine{{&stale}};
        Renderer renderer;
        require(beginFrameWithRetry(engine, renderer, &stale, timestamp),
                "completed frame was dropped because its cache was stale");
        require(renderer.attempts.size() == 2 && engine.executions == 1,
                "rejection did not drain and retry exactly once");
        for (const auto& attempt : renderer.attempts) {
            require(attempt.first == &stale && attempt.second == timestamp,
                    "retry changed swapchain or animation timestamp");
        }
    }
    {
        SwapChain busy{false, false};
        Engine engine{{&busy}};
        Renderer renderer;
        require(!beginFrameWithRetry(engine, renderer, &busy, timestamp),
                "busy GPU was forced to accept a frame");
        require(renderer.attempts.size() == 2 && engine.executions == 1,
                "busy GPU caused an unbounded retry or repeated drain");
    }
    {
        SwapChain ready{true, true}, stale{true, false};
        Engine engine{{&ready, &stale}};
        Renderer renderer;
        for (auto* swapChain : engine.swapChains) {
            require(beginFrameWithRetry(engine, renderer, swapChain, timestamp),
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
