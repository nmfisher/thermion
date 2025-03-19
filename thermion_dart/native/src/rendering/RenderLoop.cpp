#include "RenderLoop.hpp"

#include <functional>
#include <stdlib.h>
#include <time.h>

#include "Log.hpp"

namespace thermion {

RenderLoop::RenderLoop()
{
    srand(time(NULL));
    t = new std::thread([this]() { 
        while (!_stop) {
            iter();
        }
    });
}

RenderLoop::~RenderLoop()
{
    TRACE("Destroying RenderLoop");
    _stop = true;
    _cv.notify_one();
    TRACE("Joining RenderLoop thread..");    
    t->join();
    delete t;

    TRACE("RenderLoop destructor complete");    
}

void RenderLoop::requestFrame(void (*callback)())
{
    std::unique_lock<std::mutex> lock(_mutex);
    this->_requestFrameRenderCallback = callback;
    _cv.notify_one();
}

void RenderLoop::iter()
{
    {
        std::unique_lock<std::mutex> lock(_mutex);
        if (_requestFrameRenderCallback)
        {
            mRenderTicker->render(0);
            lock.unlock();
            this->_requestFrameRenderCallback();
            this->_requestFrameRenderCallback = nullptr;

            // Calculate and print FPS
            auto currentTime = std::chrono::high_resolution_clock::now();
            float deltaTime = std::chrono::duration<float, std::chrono::seconds::period>(currentTime - _lastFrameTime).count();
            _lastFrameTime = currentTime;

            _frameCount++;
            _accumulatedTime += deltaTime;

            if (_accumulatedTime >= 1.0f) // Update FPS every second
            {
                _fps = _frameCount / _accumulatedTime;
                _frameCount = 0;
                _accumulatedTime = 0.0f;
            }
        }
    }
    std::unique_lock<std::mutex> taskLock(_taskMutex);

    if (!_tasks.empty())
    {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        taskLock.unlock();
        task();
        taskLock.lock();
    }

    _cv.wait_for(taskLock, std::chrono::microseconds(2000), [this]
                { return !_tasks.empty() || _stop; });
}


} // namespace thermion