#pragma once

#include <chrono>
#include <condition_variable>
#include <deque>
#include <future>
#include <mutex>
#include <thread>

#include "RenderTicker.hpp"

#ifdef __EMSCRIPTEN__
#include <emscripten/threading.h>
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#endif

namespace thermion {

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
     * @brief Requests a frame to be rendered.
     * 
     * @param callback Callback function to be called after rendering completes
     */
    void requestFrame();

    /**
     * @brief Sets the render ticker used.
     */
    void setRenderTicker(RenderTicker *renderTicker) {
        mRenderTicker = renderTicker;
    }

    /**
     * @brief Adds a task to the render thread's task queue.
     * 
     * @param pt The packaged task to be executed
     * @return std::future<Rt> Future for the task result
     */
    template <class Rt>
    auto add_task(std::packaged_task<Rt()>& pt) -> std::future<Rt>;

    /**
     * @brief Main iteration of the render loop.
     */
    void iter();

    /**
     * 
     */
    bool _stop = false;

    
    #ifdef __EMSCRIPTEN__
    emscripten::ProxyingQueue queue;
    pthread_t outer;
    #endif

    bool mRendered = false;

private:

    bool mRender = false;
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
    RenderTicker* mRenderTicker = nullptr;
};

// Template implementation
template <class Rt>
auto RenderThread::add_task(std::packaged_task<Rt()>& pt) -> std::future<Rt> {
    
    
    std::unique_lock<std::mutex> lock(_taskMutex);
    
    auto ret = pt.get_future();
    _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(
                         std::move(pt))]
                    { (*pt)(); });
    
    _cv.notify_one();
    
    
    return ret;
}

} // namespace thermion