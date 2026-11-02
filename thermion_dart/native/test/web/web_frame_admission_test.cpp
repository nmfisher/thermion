#include "rendering/RenderManager.hpp"

#include <cstdio>
#include <cstdlib>
#include <utility>
#include <vector>

static void check(bool value, const char* message) {
    if (!value) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        std::abort();
    }
}

namespace test {
// Use the actual Filament API types, with scripted implementations below.
struct Engine : filament::Engine {
    unsigned executions = 0;
    unsigned pumps = 0;
};
struct SwapChain : filament::SwapChain {
    explicit SwapChain(std::vector<bool> results) : results(std::move(results)) {}
    std::vector<bool> results;
    size_t next = 0;
};
struct View : filament::View {};
struct Renderer : filament::Renderer {
    std::vector<std::pair<filament::SwapChain*, uint64_t>> attempts;
    std::vector<filament::SwapChain*> draws;
    std::vector<filament::SwapChain*> submissions;
    filament::SwapChain* active = nullptr;
};
unsigned pluginUpdates = 0;
}

namespace filament {
bool Renderer::beginFrame(SwapChain* swapChain, uint64_t timestamp) {
    auto& renderer = static_cast<test::Renderer&>(*this);
    auto& chain = static_cast<test::SwapChain&>(*swapChain);
    renderer.attempts.emplace_back(swapChain, timestamp);
    check(chain.next < chain.results.size(), "unexpected admission attempt");
    const bool accepted = chain.results[chain.next++];
    if (accepted) renderer.active = swapChain;
    return accepted;
}
void Renderer::render(View const*) {
    auto& renderer = static_cast<test::Renderer&>(*this);
    check(renderer.active != nullptr, "rejected frame was drawn");
    renderer.draws.push_back(renderer.active);
}
void Renderer::endFrame() {
    auto& renderer = static_cast<test::Renderer&>(*this);
    check(renderer.active != nullptr, "rejected frame was submitted");
    renderer.submissions.push_back(renderer.active);
    renderer.active = nullptr;
}
void Engine::execute() { ++static_cast<test::Engine&>(*this).executions; }
void Engine::flush() {}
void Engine::pumpMessageQueues() { ++static_cast<test::Engine&>(*this).pumps; }
}

namespace thermion {
void AnimationManager::update(uint64_t) {}
namespace plugin { void UpdatePlugins(uint64_t) { ++test::pluginUpdates; } }
}

int main() {
    constexpr uint64_t timestamp = 123456789;
    auto run = [&](std::vector<bool> results, bool accepted) {
        test::Engine engine;
        test::Renderer renderer;
        test::View view;
        test::SwapChain chain(std::move(results));
        thermion::RenderManager manager(&engine, &renderer);
        filament::View* views[] = {&view};
        manager.setRenderable(&chain, views, 1);
        const auto updates = test::pluginUpdates;
        check(manager.tick(timestamp) == accepted, "wrong admission result");
        check(chain.next == chain.results.size(), "expected attempts were skipped");
        check(renderer.draws.size() == (accepted ? 1u : 0u), "wrong draw count");
        check(renderer.submissions.size() == renderer.draws.size(), "wrong submission count");
        check(test::pluginUpdates == updates + 1, "retry repeated plugin updates");
        check(engine.executions == 1 && engine.pumps == 1,
              "retry added an execute or repeated the end-of-tick drain");
        for (const auto& attempt : renderer.attempts) {
            check(attempt.first == &chain && attempt.second == timestamp,
                  "retry changed swapchain or timestamp");
        }
    };
    run({true}, true);
    run({false, true}, true);
    run({false, false}, false);

    test::Engine engine;
    test::Renderer renderer;
    test::View view;
    test::SwapChain ready({true}), stale({false, true});
    thermion::RenderManager manager(&engine, &renderer);
    filament::View* views[] = {&view};
    manager.setRenderable(&ready, views, 1);
    manager.setRenderable(&stale, views, 1);
    const auto updates = test::pluginUpdates;
    check(manager.tick(timestamp), "both swapchains were rejected");
    check(renderer.attempts.size() == 3 && renderer.attempts[0].first == &ready &&
          renderer.attempts[1].first == &stale && renderer.attempts[2].first == &stale,
          "retry resubmitted a previously accepted swapchain");
    check(renderer.draws == std::vector<filament::SwapChain*>({&ready, &stale}) &&
          renderer.submissions == renderer.draws, "swapchains were not submitted once each");
    check(test::pluginUpdates == updates + 1 && engine.executions == 1,
          "multiple swapchains repeated updates or backend execution");
    std::puts("PASS: production render loop bounds admission retries and updates once");
}
