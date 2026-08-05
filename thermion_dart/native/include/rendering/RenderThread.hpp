#pragma once

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <functional>
#include <future>
#include <mutex>
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
 * @brief A render loop implementation that manages rendering on a separate thread.
 * 
 * This class handles frame rendering requests, viewer creation, and maintains
 * a task queue for rendering operations.
 */
class RenderThread {
public:
    /**
     * @brief Constructs a new RenderThread and starts the render thread.
     */
    explicit RenderThread();

    /**
     * @brief Destroys the RenderThread and stops the render thread.
     */
    ~RenderThread();

    /**
     * @brief Adds a task to the render thread's task queue.
     * 
     * @param pt The packaged task to be executed
     * @return std::future<Rt> Future for the task result
     */
    template <class Rt>
    auto addTask(std::packaged_task<Rt()>& pt) -> std::future<Rt>;

    /**
     * @brief Adds a fire-and-forget task without allocating a packaged-task
     * shared state or future.
     *
     * Use this for callbacks whose completion is communicated by another
     * mechanism (for example, the Dart request-id callback).
     */
    template <class Fn>
    void addDetachedTask(Fn&& fn);


    #ifdef __EMSCRIPTEN__
    /**
     * @brief Main iteration of the browser-driven render loop.
     */
    void iter();
    #endif

    /**
     * Per-instance worker shutdown signal, heap-allocated and shared with the
     * worker via a std::shared_ptr copy. Native workers exit after draining
     * queued tasks; web workers exit on their next browser-loop iteration.
     *
     * The flag must outlive `this`: on web pthread_detach lets the destructor
     * return and `*this` be freed before the worker observes the signal, so a
     * plain member would be UAF. The worker only dereferences the RenderThread
     * after observing the flag is false, which keeps the window closed (the
     * destructor sets the flag before draining and detaching, so the worker
     * never touches `this` after shutdown begins).
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

    #ifdef __EMSCRIPTEN__
    emscripten::ProxyingQueue queue;
    pthread_t outer;

    // Web-only: iter() invokes mRenderManager->tick() on each rAF so rendering
    // is driven by the browser's frame cadence rather than a Dart-queued task.
    void setRenderManager(RenderManager* rm) { mRenderManager = rm; }
    RenderManager* mRenderManager = nullptr;
    #endif

private:
    #ifndef __EMSCRIPTEN__
    void runNativeLoop();
    #endif

    std::mutex _taskMutex;
    std::condition_variable _cv;
    std::deque<std::function<void()>> _tasks;
    std::chrono::high_resolution_clock::time_point _lastFrameTime;
    int _frameCount = 0;
    float _accumulatedTime = 0.0f;
    float _fps = 0.0f;


#ifdef __EMSCRIPTEN__
    pthread_t t;
#else
    std::thread* t = nullptr;
#endif
};

// Template implementation
template <class Rt>
auto RenderThread::addTask(std::packaged_task<Rt()>& pt) -> std::future<Rt> {
    auto ret = pt.get_future();
    {
        std::lock_guard<std::mutex> lock(_taskMutex);
        _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(
                             std::move(pt))]
                        { (*pt)(); });
    }
    #ifndef __EMSCRIPTEN__
    _cv.notify_one();
    #endif
    return ret;
}

template <class Fn>
void RenderThread::addDetachedTask(Fn&& fn) {
    // Construct outside the critical section since std::function may need to
    // allocate for a large capture.
    std::function<void()> task(std::forward<Fn>(fn));
    {
        std::lock_guard<std::mutex> lock(_taskMutex);
        _tasks.push_back(std::move(task));
    }
    #ifndef __EMSCRIPTEN__
    _cv.notify_one();
    #endif
}

} // namespace thermion
