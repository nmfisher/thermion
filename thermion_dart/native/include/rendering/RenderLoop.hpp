#pragma once

#include <chrono>
#include <condition_variable>
#include <deque>
#include <future>
#include <mutex>
#include <thread>

#include "RenderTicker.hpp"

namespace thermion {

/**
 * @brief A render loop implementation that manages rendering on a separate thread.
 * 
 * This class handles frame rendering requests, viewer creation, and maintains
 * a task queue for rendering operations.
 */
class RenderLoop {
public:
    /**
     * @brief Constructs a new RenderLoop and starts the render thread.
     */
    explicit RenderLoop();

    /**
     * @brief Destroys the RenderLoop and stops the render thread.
     */
    ~RenderLoop();

    /**
     * @brief Requests a frame to be rendered.
     * 
     * @param callback Callback function to be called after rendering completes
     */
    void requestFrame(void (*callback)());

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

private:
    /**
     * @brief Main iteration of the render loop.
     */
    void iter();

    void (*_requestFrameRenderCallback)() = nullptr;
    bool _stop = false;
    std::mutex _mutex;
    std::mutex _taskMutex;
    std::condition_variable _cv;
    std::deque<std::function<void()>> _tasks;
    std::chrono::high_resolution_clock::time_point _lastFrameTime;
    int _frameCount = 0;
    float _accumulatedTime = 0.0f;
    float _fps = 0.0f;
    std::thread* t = nullptr;
    RenderTicker* mRenderTicker = nullptr;
};

// Template implementation
template <class Rt>
auto RenderLoop::add_task(std::packaged_task<Rt()>& pt) -> std::future<Rt> {
    std::unique_lock<std::mutex> lock(_taskMutex);
    auto ret = pt.get_future();
    _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(
                         std::move(pt))]
                    { (*pt)(); });
    _cv.notify_one();
    return ret;
}

} // namespace thermion