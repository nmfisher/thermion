#pragma once

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <future>
#include <mutex>
#include <thread>

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
     * @brief Main iteration of the render loop.
     */
    void iter();

    /**
     * Signals the worker to exit on its next iteration. Written by the
     * destructor (true) and the constructor (false) on the main thread, read
     * by the worker.
     *
     * Static, not an instance member, because on web pthread_detach lets the
     * destructor return and `*this` be freed before the worker observes the
     * flag — a member would be UAF. Native could safely use a member (`t->join()`
     * keeps `*this` alive across the worker's read) but the static works there
     * too since RenderThread is a singleton, and one mechanism is simpler than
     * two. RenderThread being a singleton is an existing invariant
     * (`_renderThread` in ThermionDartRenderThreadApi.cpp); breaking it would
     * require revisiting this design.
     *
     * On web, create() after destroy() must wait for mLiveWorkerCount to hit 0
     * before constructing the next RenderThread, otherwise the constructor's
     * reset to false races the previous worker's read of true.
     */
    static std::atomic<bool> mStop;

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
    
    std::unique_lock<std::mutex> lock(_taskMutex);
    
    auto ret = pt.get_future();
    _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(
                         std::move(pt))]
                    { (*pt)(); });
    #ifndef __EMSCRIPTEN__
    _cv.notify_one();
    #endif
    
    
    return ret;
}

} // namespace thermion