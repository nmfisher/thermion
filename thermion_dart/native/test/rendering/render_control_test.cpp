#include "Plugin.hpp"
#include "rendering/RenderManager.hpp"

#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <mutex>
#include <thread>

using namespace std::chrono_literals;

// Plugin updates run under the same render-manager mutex as Filament's upload
// release callbacks. Hold an update until the caller has issued a control,
// reproducing the worker -> main -> render mutex circular wait without a GPU.
class PendingCallback final : public thermion::plugin::Plugin {
public:
    const char* getName() const override { return "render-control-test"; }
    void update(uint64_t) override {
        std::unique_lock lock(mutex);
        ++updates;
        entered = true;
        cv.notify_all();
        cv.wait(lock, [&] { return released; });
    }

    std::mutex mutex;
    std::condition_variable cv;
    bool entered = false;
    bool released = false;
    bool timedOut = false;
    int updates = 0;
};

int main() {
    PendingCallback callback;
    thermion::plugin::RegisterPlugin(callback.getName(), &callback);
    // With no attachments, native tick() needs neither an Engine nor Renderer.
    // Its plugin update and control methods use the same code as web.
    thermion::RenderManager manager(nullptr, nullptr);
    std::thread worker([&] { manager.tick(0); });
    {
        std::unique_lock lock(callback.mutex);
        if (!callback.cv.wait_for(lock, 3s, [&] { return callback.entered; })) {
            std::fputs("FAIL: worker did not enter plugin update\n", stderr);
            std::abort();
        }
    }
    // Release a broken implementation after a timeout so the test reports a
    // failure instead of hanging. A correct control returns before release.
    std::thread watchdog([&] {
        std::unique_lock lock(callback.mutex);
        if (!callback.cv.wait_for(lock, 3s, [&] { return callback.released; })) {
            callback.timedOut = true;
            callback.released = true;
            callback.cv.notify_all();
        }
    });
    manager.setPaused(true);
    {
        std::lock_guard lock(callback.mutex);
        callback.released = true;
        callback.cv.notify_all();
    }
    worker.join();
    watchdog.join();
    if (callback.timedOut) {
        std::fputs("FAIL: pause waited for the in-flight callback\n", stderr);
        return 1;
    }
    manager.tick(1);
    if (callback.updates != 1) return 1;
    manager.setPaused(false);
    manager.tick(2);
    if (callback.updates != 2) return 1;
    std::puts("PASS: pause returns while a render callback is pending");
}
