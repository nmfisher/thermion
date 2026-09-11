#include "rendering/RenderThread.hpp"
#include "rendering/RenderManager.hpp"
#include <emscripten.h>
#include <atomic>
#include <chrono>
#include <cstdlib>

using namespace thermion;
// Exercise the production queue without creating a Filament engine.
namespace thermion { bool RenderManager::tick(uint64_t) { return false; } }
namespace thermion { void RenderManager::executePendingCommands() {} }

static std::atomic<int> executed{0};
static bool completed = false; // browser-only
static int roundNumber = 0;
static int polls = 0;
static bool yielded = false; // worker-only; reset before starting a new worker

static void check(bool condition, const char* message) {
    if (!condition) {
        EM_ASM({ globalThis.testResult = 'FAIL: ' + UTF8ToString($0); }, message);
        std::abort();
    }
}

static void startRound(void*);
static void poll(void*) {
    if (completed && RenderThread::mLiveWorkerCount == 0) {
        check(executed == 200, "shutdown lost tasks");
        if (++roundNumber == 25) {
            EM_ASM({ globalThis.testResult = 'PASS: 25 worker shutdown cycles, FIFO, yielding, callbacks after worker exit, rAF disabled'; });
            return;
        }
        emscripten_set_timeout(startRound, 0, nullptr);
        return;
    }
    check(++polls < 1000, "worker or completion failed to finish");
    emscripten_set_timeout(poll, 5, nullptr);
}

static void startRound(void*) {
    completed = false;
    polls = 0;
    executed = 0;
    yielded = false;
    auto owner = RenderThread::create("");
    check(owner != nullptr, "worker failed to start");
    auto* raw = owner.get();
    for (int i = 0; i < 200; ++i) {
        raw->addDetachedTask([i] {
            check(!emscripten_is_main_browser_thread(), "task ran on the browser thread");
            check(executed.fetch_add(1) == i, "queue violated FIFO");
            if (i == 0) emscripten_set_timeout([](void*) { yielded = true; }, 0, nullptr);
            const auto end = std::chrono::steady_clock::now() + std::chrono::microseconds(50);
            while (std::chrono::steady_clock::now() < end) {}
        });
    }
    raw->addDetachedTask([raw] {
        check(yielded, "task batches did not yield to the worker event loop");
        // Already accepted work can still queue its completion while draining.
        raw->addDetachedTask([raw] {
            raw->dispatchCallback([] {
                check(emscripten_is_main_browser_thread(), "completion ran on worker");
                completed = true;
            });
        });
    });
    RenderThread::destroy(std::move(owner)); // do not access raw again
    // Keep the browser busy until the worker exits. Completion delivery must
    // still work afterward, without manually executing a proxy queue.
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (RenderThread::mLiveWorkerCount != 0 && std::chrono::steady_clock::now() < deadline) {}
    check(RenderThread::mLiveWorkerCount == 0, "worker shutdown needed browser callback servicing");
    emscripten_set_timeout(poll, 0, nullptr);
}

int main() {
    emscripten_set_timeout(startRound, 0, nullptr);
    emscripten_exit_with_live_runtime();
}
