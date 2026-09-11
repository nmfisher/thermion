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

/**
 * @brief A render loop that executes Filament work on a dedicated worker
 *        thread, one ordered command queue per engine.
 *
 * Dart-facing API calls are packaged as commands and appended to the queue;
 * the worker normally executes them in FIFO order. On web, each animation
 * frame drains the queue without yielding, then draws. Drawing does not
 * interleave with commands within that drain.
 *
 * Native workers sleep on a condition variable until work arrives and are
 * drained and joined during destruction. Web workers are browser pthreads:
 * they service the queue on each animation frame (iter()). Web destruction
 * still runs remaining queued commands on the caller's thread and detaches
 * the worker. Worker affinity during web teardown is therefore not guaranteed;
 * fixing that lifecycle is separate from this rearrangement.
 */
class RenderThread {
public:
    /**
     * @brief Constructs a new RenderThread and starts the render thread.
     *
     * @param canvasSelector Web-only: the CSS selector of the canvas element
     *        transferred to this thread's worker (default "#thermion_canvas").
     *        Each engine-per-viewer thread owns its own canvas.
     */
    explicit RenderThread(const char* canvasSelector = "#thermion_canvas");

    /**
     * @brief Destroys the RenderThread and stops the render thread.
     *
     * Signals the worker to exit. Native destruction joins after the worker
     * drains its queue. Web destruction drains remaining commands on the
     * caller's thread and detaches, without waiting for the worker to exit.
     */
    ~RenderThread();

    /**
     * @brief The CSS selector of the canvas transferred to this thread's
     *        worker (web only). Used by Engine_create to create the WebGL
     *        context on the right canvas.
     */
    const char* canvasSelector() const { return _canvasSelector.c_str(); }

    /**
     * @brief True when the worker pthread failed to start (web). The C API
     *        returns a null handle in that case so Dart can fail loudly
     *        instead of hanging on tasks that will never run.
     */
    bool creationFailed() const { return _creationFailed; }

    /**
     * @brief True once shutdown has been requested (see shutdown()).
     */
    bool isStopping() const { return _stop->value.load(std::memory_order_acquire); }

    /**
     * @brief Signals the worker to exit. Called by destruction; native workers
     *        wake and drain their queue. Web workers stop at their next
     *        animation-frame iteration, before draining; the web destructor
     *        handles remaining commands on the caller's thread.
     */
    void shutdown();

    /**
     * @brief Adds a task to the render thread's task queue.
     *
     * @param task The packaged task to be executed
     * @return std::future<Rt> Future for the task result
     */
    template <class Rt>
    auto addTask(std::packaged_task<Rt()>& task) -> std::future<Rt>;

    /**
     * @brief Adds a fire-and-forget task without allocating a packaged-task
     * shared state or future.
     *
     * Use this for callbacks whose completion is communicated by another
     * mechanism (for example, the Dart request-id callback).
     */
    template <class Fn>
    void addDetachedTask(Fn&& fn) {
        enqueue(std::function<void()>(std::forward<Fn>(fn)));
    }

    #ifdef __EMSCRIPTEN__
    /**
     * @brief Main iteration of the browser-driven render loop.
     */
    void iter();

    emscripten::ProxyingQueue queue;
    pthread_t outer;

    // Web-only: iter() invokes _renderManager->tick() on each rAF so rendering
    // is driven by the browser's frame cadence rather than a Dart-queued task.
    void setRenderManager(RenderManager* rm) { _renderManager = rm; }
    RenderManager* _renderManager = nullptr;
    #endif

    /**
     * Per-instance worker shutdown signal, heap-allocated and shared with the
     * worker via a std::shared_ptr copy. Native workers exit after draining
     * queued tasks; web workers exit on their next browser-loop iteration.
     *
     * The flag must outlive `this`: on web pthread_detach lets the destructor
     * return and `*this` be freed before the worker observes the signal, so a
     * plain member would be UAF. The flag keeps the stop check alive, but
     * does not protect `this` if shutdown starts after the worker has checked
     * the flag. Coordinating web object destruction with the worker remains
     * a separate lifecycle fix.
     *
     * Per-instance, not static: with one engine per thread, destroying one
     * engine's RenderThread must not signal another engine's worker (a shared
     * static flag would stop every worker in the module).
     */
    struct StopFlag {
        std::atomic<bool> value{false};
    };
    std::shared_ptr<StopFlag> stopFlag() const { return _stop; }
    std::shared_ptr<StopFlag> _stop = std::make_shared<StopFlag>();

    /**
     * Live worker count. Incremented on worker entry, decremented just before
     * the worker exits. Polled from the main thread before constructing a
     * replacement RenderThread on web, since pthread_detach lets the destructor
     * return before the worker has actually exited.
     */
    static std::atomic<int32_t> mLiveWorkerCount;

private:
    #ifndef __EMSCRIPTEN__
    void runNativeLoop();
    #else
    void startWebWorker(const char* canvasSelector);
    void pumpTasks();
    #endif

    // Appends one command to the queue. Native workers are woken immediately;
    // web workers service the queue on their next animation-frame iteration.
    void enqueue(std::function<void()> task);

    std::mutex _taskMutex;
    std::condition_variable _cv;
    std::deque<std::function<void()>> _tasks;
    // Owned copy: the Dart side frees its UTF8 buffer right after
    // RenderThread_createForCanvas returns, and Engine_create reads the
    // selector later (during the same serialized engine creation).
    std::string _canvasSelector = "#thermion_canvas";
    bool _creationFailed = false;


#ifdef __EMSCRIPTEN__
    pthread_t _thread{};
#else
    std::thread* _thread = nullptr;
#endif
};

// Template implementation
template <class Rt>
auto RenderThread::addTask(std::packaged_task<Rt()>& task) -> std::future<Rt> {
    auto result = task.get_future();
    addDetachedTask([task = std::make_shared<std::packaged_task<Rt()>>(
                         std::move(task))] { (*task)(); });
    return result;
}

} // namespace thermion
