#pragma once

#include "rendering/JobThreadBase.hpp"
#include <atomic>
#include <condition_variable>
#include <memory>
#include <thread>

namespace thermion {

// A blocking FIFO worker. Sleeps until work arrives; destruction drains and
// joins before returning. Drawing is scheduled separately on native platforms.
class NativeJobThread final : public JobThreadBase {
public:
    NativeJobThread();
    ~NativeJobThread() override;

    // Matches the shared creation API; the canvas selector is unused on native.
    static std::unique_ptr<NativeJobThread> create(const char* = nullptr);
    // Consumes ownership. Previously accepted work finishes before this returns.
    static void destroy(std::unique_ptr<NativeJobThread> thread);

    bool isStopping() const override { return _stopping.load(std::memory_order_acquire); }

private:
    void enqueue(std::function<void()> task) override;
    void run();

    std::condition_variable _cv;
    std::atomic<bool> _stopping{false};
    std::thread _thread;
};

} // namespace thermion
