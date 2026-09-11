#pragma once

#include <atomic>
#include <condition_variable>
#include <deque>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>

#ifdef __EMSCRIPTEN__
#include <emscripten/threading.h>
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#endif

namespace thermion {

class RenderManager;

// One ordered command queue per engine. Native workers sleep until work arrives;
// web workers service bounded batches from event notifications independently of
// their drawing loop. Filament calls always execute on the owning worker.
// FIFO applies to commands, not transactions: drawing may run between batches.
class RenderThread {
public:
    explicit RenderThread(const char* canvasSelector = "#thermion_canvas");
    ~RenderThread();

    const char* canvasSelector() const { return _canvasSelector.c_str(); }
    bool creationFailed() const { return _creationFailed; }
    bool isStopping() const { return _stopping.load(std::memory_order_acquire); }

    // Drain accepted work. Native destruction joins the worker. On web this
    // transfers ownership to the worker, which deletes this object after its
    // queue and frame loop stop. Call only once on a heap-allocated web worker;
    // the caller must release its owner before calling and never use it again.
    void shutdown();

    template <class Rt>
    auto addTask(std::packaged_task<Rt()>& task) -> std::future<Rt>;

    template <class Fn>
    void addDetachedTask(Fn&& fn) { enqueue(std::function<void()>(std::forward<Fn>(fn))); }

    static std::atomic<int32_t> mLiveWorkerCount;

#ifdef __EMSCRIPTEN__
    // Completion delivery uses a module-lifetime queue, so accepted callbacks
    // remain deliverable after the originating engine/worker has shut down.
    void dispatchCallback(std::function<void()> callback) const;
    static void executeCallbacks();
    void setRenderManager(RenderManager* manager); // worker-only
#else
    void dispatchCallback(std::function<void()> callback) const { callback(); }
#endif

private:
    void enqueue(std::function<void()> task);
    bool isWorkerThread() const;

    std::mutex _taskMutex;
    std::condition_variable _cv;
    std::deque<std::function<void()>> _tasks;
    std::atomic<bool> _stopping{false};
    // Dart frees its UTF8 buffer immediately after worker creation.
    std::string _canvasSelector;
    bool _creationFailed = false;

#ifdef __EMSCRIPTEN__
    void startWebWorker();
    static void* startHelper(void* arg);
    static void frameCallback(void* arg);
    static void pumpCallback(void* arg);
    static void finishShutdown(void* arg);
    void scheduleWakeLocked();
    void pumpTasks();

    pthread_t _thread{};
    pthread_t _caller{};
    bool _wakePending = false; // protected by _taskMutex
    bool _workerFinished = false;
    RenderManager* _renderManager = nullptr; // worker-only
#else
    void runNativeLoop();
    std::thread _thread;
#endif
};

template <class Rt>
auto RenderThread::addTask(std::packaged_task<Rt()>& task) -> std::future<Rt> {
    auto result = task.get_future();
    addDetachedTask([task = std::make_shared<std::packaged_task<Rt()>>(std::move(task))] {
        (*task)();
    });
    return result;
}

} // namespace thermion
