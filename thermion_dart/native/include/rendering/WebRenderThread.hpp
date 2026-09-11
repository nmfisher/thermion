#pragma once

#include <atomic>
#include <cstdint>
#include <deque>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <emscripten/threading.h>

namespace thermion {

class RenderManager;

// An event-driven worker: commands run in yielding FIFO batches independently
// of animation-frame drawing. Drawing can happen between batches, so a group
// of commands is not an atomic transaction. Use create()/destroy() for ownership.
class WebRenderThread {
public:
    explicit WebRenderThread(const char* canvasSelector);
    ~WebRenderThread();

    // Returns null if the pthread cannot start. Owns a copy of the selector.
    static std::unique_ptr<WebRenderThread> create(const char* canvasSelector = nullptr);
    // Consumes ownership and returns without blocking the browser. The worker
    // drains, cancels its frame loop, then deletes itself. Never use it afterward.
    static void destroy(std::unique_ptr<WebRenderThread> thread);

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

    const char* canvasSelector() const { return _canvasSelector.c_str(); }

    // Posted callbacks outlive their worker and are serviced by browser events.
    void dispatchCallback(std::function<void()> callback) const;
    static void executeCallbacks();
    void setRenderManager(RenderManager* manager); // worker-only
    static std::atomic<int32_t> mLiveWorkerCount;

private:
    void startWorker();
    void requestShutdown();
    void enqueue(std::function<void()> task);
    void scheduleWakeLocked();
    void pumpTasks();
    static void* startHelper(void* arg);
    static void frameCallback(void* arg);
    static void pumpCallback(void* arg);
    static void finishShutdown(void* arg);

    std::mutex _taskMutex;
    std::deque<std::function<void()>> _tasks;
    std::atomic<bool> _stopping{false};
    // Dart frees its UTF8 buffer immediately after worker creation.
    std::string _canvasSelector;
    bool _creationFailed = false;
    pthread_t _thread{};
    pthread_t _caller{};
    bool _wakePending = false; // protected by _taskMutex
    bool _workerFinished = false;
    RenderManager* _renderManager = nullptr; // worker-only
};

} // namespace thermion
