#include "rendering/RenderThread.hpp"
#include "rendering/RenderManager.hpp"

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
std::chrono::high_resolution_clock::time_point loopExitTime;
bool loopExitTimeValid = false;

static void mainLoop(void* arg) {
    auto *rt = static_cast<RenderThread *>(arg);
    // If the render thread has been asked to stop, break the loop and exit immediately.
    if (rt->mStop) {
        emscripten_cancel_main_loop();
        loopExitTime = std::chrono::high_resolution_clock::now();
        loopExitTimeValid = true;
        return;
    }

    rt->iter();
    loopExitTime = std::chrono::high_resolution_clock::now();
    loopExitTimeValid = true;
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
    _lastFrameTime = std::chrono::high_resolution_clock::now();
    #ifdef __EMSCRIPTEN__
    Log("Starting RenderThread")
    outer = pthread_self();
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    emscripten_pthread_attr_settransferredcanvases(&attr, "#thermion_canvas");
    pthread_create(&t, &attr, startHelper, this);
    #else
    t = new std::thread([this]() { 
        while (!mStop) {
            iter();
        }
    });
    #endif
}



RenderThread::~RenderThread()
{
    TRACE("Destroying RenderThread (%lu tasks remaining)", _tasks.size());
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
    // Waiting for the main loop to exit before continuing
    pthread_join(t, nullptr);
    #else
    t->join();
    delete t;
    #endif

    TRACE("RenderThread destructor complete");    
}

void RenderThread::iter()
{
    // FPS measurement
    auto now = std::chrono::high_resolution_clock::now();
    float deltaTime = std::chrono::duration<float>(now - _lastFrameTime).count();

    std::unique_lock<std::mutex> taskLock(_taskMutex);

#ifdef __EMSCRIPTEN__
    // On Emscripten, drain all queued tasks then yield to browser.
    while (!_tasks.empty())
    {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        taskLock.unlock();
        task();
        taskLock.lock();
    }
    taskLock.unlock();

    // Render at most one swapchain per rAF so Filament's WebGL backend can
    // commit the frame between iterations. When no render has been requested,
    // tick() is a cheap flag-check and returns immediately.
    if (mRenderManager) {
        auto frameTimeInNanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                                    now.time_since_epoch()).count();
        mRenderManager->tick(frameTimeInNanos);
    }
#else
    // On native, process one task then wait for more
    if (!_tasks.empty())
    {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        taskLock.unlock();
        task();
        taskLock.lock();
    }
    _cv.wait_for(taskLock, std::chrono::microseconds(2000), [this]
                { return !_tasks.empty() || mStop; });
#endif
}

} // namespace thermion
