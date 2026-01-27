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
std::chrono::high_resolution_clock::time_point loopExitTime;
bool loopExitTimeValid = false;

static void mainLoop(void* arg) {
    auto *rt = static_cast<RenderThread *>(arg);
    rt->mMainLoopActive.store(true);

    if (!rt->mStop) {
        rt->iter();
    }

    rt->mMainLoopActive.store(false);
    loopExitTime = std::chrono::high_resolution_clock::now();
    loopExitTimeValid = true;
}

static void *startHelper(void * parm) {
    loopStart = std::chrono::high_resolution_clock::now();
    emscripten_set_main_loop_arg(&mainLoop, parm, 0, true);
    return nullptr;
}

static void processTasksAsync(void* arg) {
    auto *rt = static_cast<RenderThread *>(arg);
    rt->processAsyncTasks();
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
    Log("Destroying RenderThread (%lu tasks remaining)", _tasks.size());
    mStop = true;
    _cv.notify_one();
    TRACE("Joining RenderThread thread..");    
    
    while (!_tasks.empty())
    {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        task();
    }
    #ifndef __EMSCRIPTEN__
    t->join();
    delete t;
    #endif

    Log("RenderThread destructor complete");    
}

void RenderThread::iter()
{
    // FPS measurement
    auto now = std::chrono::high_resolution_clock::now();
    float deltaTime = std::chrono::duration<float>(now - _lastFrameTime).count();

    std::unique_lock<std::mutex> taskLock(_taskMutex);

#ifdef __EMSCRIPTEN__
    // On Emscripten, process tasks until render() completes, then yield to browser.
    // This ensures the frame is displayed promptly while deferring other tasks.
    while (!_tasks.empty())
    {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        taskLock.unlock();
        task();
        taskLock.lock();

        // Yield after render() completes to let browser display the frame
        if (mRenderCompleted.load()) {
            mRenderCompleted.store(false);
            if (!_tasks.empty()) {
                TRACE("Scheduling %zu deferred tasks for async processing", _tasks.size());
                emscripten_async_call(processTasksAsync, this, 0);
            }
            break;
        }
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

#ifdef __EMSCRIPTEN__
void RenderThread::processAsyncTasks() {
    // Stop if mainLoop has started (next frame beginning)
    if (mMainLoopActive.load() || mStop) {
        return;
    }

    std::unique_lock<std::mutex> taskLock(_taskMutex);

    if (_tasks.empty()) {
        return;
    }

    auto task = std::move(_tasks.front());
    _tasks.pop_front();
    size_t remaining = _tasks.size();
    taskLock.unlock();

    TRACE("Async processing task (%zu remaining)", remaining);
    task();

    // Schedule next task if there are more and mainLoop hasn't started
    if (remaining > 0 && !mMainLoopActive.load()) {
        emscripten_async_call(processTasksAsync, this, 0);
    }
}
#endif

} // namespace thermion
