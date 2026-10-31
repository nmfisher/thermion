#pragma once

#include "rendering/JobThreadBase.hpp"
#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <utility>
#include <emscripten/threading.h>

namespace thermion {

// An event-driven worker: commands run in yielding FIFO batches independently
// of animation-frame drawing. Drawing can happen between batches, so a group
// of commands is not an atomic transaction. Use create()/destroy() for ownership.
// THERMION_WEB_MAIN_THREAD executes commands inline without starting a worker.
class WebJobThread final : public JobThreadBase {
public:
    explicit WebJobThread(const char* canvasSelector);
    ~WebJobThread() override;

    // Returns null if the pthread cannot start. Owns a copy of the selector.
    static std::unique_ptr<WebJobThread> create(const char* canvasSelector = "#thermion_canvas");
    // Consumes ownership and returns without blocking the browser. The worker
    // drains accepted work, then deletes itself. Never use it afterward.
    static void destroy(std::unique_ptr<WebJobThread> thread);

    bool isStopping() const override { return _stopping.load(std::memory_order_acquire); }

    // Borrowed selector for the job running on this thread; null outside a job.
    static const char* currentCanvasSelector();

    // Posted callbacks outlive their worker and are serviced by browser events.
    void dispatchCallback(std::function<void()> callback) const;
    static void executeCallbacks();
    // Called on the owning thread. Clear it before destroying its captures.
    void setAfterBatchCallback(std::function<void()> callback) {
        _afterBatch = std::move(callback);
    }
    static std::atomic<int32_t> mLiveWorkerCount;

private:
    class CurrentThreadScope;
    static thread_local WebJobThread* _current;

    void startWorker();
    void requestShutdown();
    bool isWorkerThread() const;
    void runAfterBatchCallback();
    void enqueue(std::function<void()> task) override;
    void scheduleWakeLocked();
    void pumpTasks();
    static void* startHelper(void* arg);
    static void pumpCallback(void* arg);
    static void finishShutdown(void* arg);

    std::atomic<bool> _stopping{false};
    // Dart frees its UTF8 buffer immediately after worker creation.
    std::string _canvasSelector;
    bool _creationFailed = false;
    // Worker that runs queued commands. Wakeups are posted to this thread.
    // In THERMION_WEB_MAIN_THREAD mode, this is the same thread as _caller.
    pthread_t _thread{};
    // Thread that created this object, normally the browser main thread running
    // Dart. Command completion callbacks run on this thread.
    pthread_t _caller{};
    bool _wakePending = false; // protected by _taskMutex
    bool _workerFinished = false;
    std::function<void()> _afterBatch;
};

} // namespace thermion
