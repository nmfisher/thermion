#include "rendering/RenderThread.hpp"

#include <functional>
#include <stdlib.h>
#include <time.h>

#include "Log.hpp"

namespace thermion {

#ifdef __EMSCRIPTEN__
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#include "ThermionWebApi.h"

static void mainLoop(void* arg) {
    auto *rt = static_cast<RenderThread *>(arg);

    if (!rt->_stop) {
        rt->iter();
    } else { 
        Log("RenderThread stopped")
    }
}

static void *startHelper(void * parm) {
    emscripten_set_main_loop_arg(&mainLoop, parm, 0, true);
    return nullptr;
}

#endif

RenderThread::RenderThread()
{
    srand(time(NULL));
    #ifdef __EMSCRIPTEN__
    outer = pthread_self();
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    emscripten_pthread_attr_settransferredcanvases(&attr, "#thermion_canvas");
    pthread_create(&t, &attr, startHelper, this);
    #else
    t = new std::thread([this]() { 
        while (!_stop) {
            iter();
        }
    });
    #endif
}



RenderThread::~RenderThread()
{
    Log("Destroying RenderThread (%d tasks remaining)", _tasks.size());
    _stop = true;
    _cv.notify_one();
    TRACE("Joining RenderThread thread..");    
    
    while (!_tasks.empty())
    {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        task();
    }
    #ifdef __EMSCRIPTEN__
    pthread_join(t, NULL);
    #else
    t->join();
    delete t;
    #endif

    TRACE("RenderThread destructor complete");    
}

void RenderThread::requestFrame(void (*callback)())
{
    TRACE("Request frame");
    std::unique_lock<std::mutex> lock(_mutex);
    this->_requestFrameRenderCallback = callback;
    _cv.notify_one();
}

void RenderThread::iter()
{
    {
        #ifdef __EMSCRIPTEN__
        queue.execute();
        #endif
        std::unique_lock<std::mutex> lock(_mutex);
        if (_requestFrameRenderCallback)
        {
            mRenderTicker->render(0);
            lock.unlock();
            #ifdef __EMSCRIPTEN__
            queue.proxyAsync(outer, [=]() {
            #endif
            this->_requestFrameRenderCallback();
            #ifdef __EMSCRIPTEN__
            });
            queue.execute();
            #endif

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