#include "rendering/RenderThread.hpp"

#include <functional>
#include <stdlib.h>
#include <time.h>
#include <chrono>

#include "Log.hpp"

namespace thermion {

#ifdef __EMSCRIPTEN__
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#include "ThermionWebApi.h"

std::chrono::high_resolution_clock::time_point loopStart;

static void mainLoop(void* arg) {
    auto *rt = static_cast<RenderThread *>(arg);
  
    auto startTime = std::chrono::high_resolution_clock::now();

    auto timeSinceLastLoopStart = std::chrono::duration_cast<std::chrono::milliseconds>(startTime - loopStart).count();

    loopStart = startTime;
    rt->mRestart = false;
    rt->mRendered = false;
    long long elapsed = 0;
    int numIters = 0;
    while (!rt->mStop && !rt->mRestart && elapsed < 12) {
        rt->iter();
        numIters++;
        auto now = std::chrono::high_resolution_clock::now();
        elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - startTime).count();
    } 

    if(rt->mStop) {
        Log("RenderThread stopped")
        emscripten_set_main_loop_arg(nullptr, nullptr, 0, true);
    }

}

static void *startHelper(void * parm) {
    loopStart = std::chrono::high_resolution_clock::now();
    emscripten_set_main_loop_arg(&mainLoop, parm, 0, true);
    return nullptr;
}

#endif

void RenderThread::restart() { 
    #ifdef __EMSCRIPTEN__
    mRestart = true;
    #endif
}

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
        while (!mStop) {
            iter();
            mRendered = false;
        }
    });
    #endif
}



RenderThread::~RenderThread()
{
    Log("Destroying RenderThread (%d tasks remaining)", _tasks.size());
    mStop = true;
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

void RenderThread::requestFrame()
{
    if(mRendered) {
        return;
    }
    if(mRender) {
        TRACE("Warning - frame requested before previous frame has completed rendering");
    }
    mRender = true;
    #ifndef __EMSCRIPTEN__
    _cv.notify_one();
    #endif
}

void RenderThread::iter()
{
    if (mRender && !mRendered)
    {
        if(mRenderTicker->render(0)) {
            mRender = false;
            mRendered = true;
        
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
    #ifndef __EMSCRIPTEN__
    _cv.wait_for(taskLock, std::chrono::microseconds(2000), [this]
                { return !_tasks.empty() || mStop; });
    #endif

}


} // namespace thermion
