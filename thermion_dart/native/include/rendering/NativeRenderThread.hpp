#pragma once

#include <atomic>
#include <condition_variable>
#include <deque>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <thread>
#include <utility>

namespace thermion {

// A blocking FIFO worker. Sleeps until work arrives; destruction drains and
// joins before returning. Drawing is scheduled separately on native platforms.
class NativeRenderThread {
public:
    NativeRenderThread();
    ~NativeRenderThread();

    // Matches the shared creation API; the canvas selector is unused on native.
    static std::unique_ptr<NativeRenderThread> create(const char* = nullptr);
    // Consumes ownership. Previously accepted work finishes before this returns.
    static void destroy(std::unique_ptr<NativeRenderThread> thread);

    template <class Rt>
    auto addTask(std::packaged_task<Rt()>& task) -> std::future<Rt> {
        auto result = task.get_future();
        addDetachedTask([task = std::make_shared<std::packaged_task<Rt()>>(std::move(task))] {
            (*task)();
        });
        return result;
    }

    template <class Fn>
    void addDetachedTask(Fn&& fn) {
        enqueue(std::function<void()>(std::forward<Fn>(fn)));
    }

    bool isStopping() const { return _stopping.load(std::memory_order_acquire); }

private:
    void enqueue(std::function<void()> task);
    void run();

    std::mutex _taskMutex;
    std::condition_variable _cv;
    std::deque<std::function<void()>> _tasks;
    std::atomic<bool> _stopping{false};
    std::thread _thread;
};

} // namespace thermion
