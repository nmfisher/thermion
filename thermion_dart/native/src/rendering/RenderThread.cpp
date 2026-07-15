#include "rendering/RenderThread.hpp"
#include "rendering/RenderManager.hpp"

#include <functional>
#include <stdlib.h>
#include <time.h>
#include <chrono>

#include "Log.hpp"

namespace thermion {

std::atomic<bool> RenderThread::mStop{false};
std::atomic<int32_t> RenderThread::mLiveWorkerCount{0};

#ifdef __EMSCRIPTEN__
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#include <mimalloc.h>
#include "ThermionWebApi.h"

std::chrono::high_resolution_clock::time_point loopStart;
std::chrono::high_resolution_clock::time_point loopExitTime;
bool loopExitTimeValid = false;

static void mainLoop(void* arg) {
    // Check the stop flag BEFORE touching `arg` — the destructor may have
    // returned (via pthread_detach) and `*this` may already be freed. mStop
    // is a static, so the read is safe regardless.
    if (RenderThread::mStop.load()) {
        emscripten_cancel_main_loop();
        loopExitTime = std::chrono::high_resolution_clock::now();
        loopExitTimeValid = true;
        // mimalloc reserves a per-thread arena (~32 MiB initial on wasm32)
        // that survives pthread_exit unless we explicitly release it.
        mi_thread_done();
        RenderThread::mLiveWorkerCount.fetch_sub(1, std::memory_order_relaxed);
        // emscripten_set_main_loop_arg(..., simulate_infinite_loop=true) threw
        // to unwind startHelper, so the pthread function never returned. The
        // JS-side worker would otherwise stay alive in the event loop after
        // emscripten_cancel_main_loop; explicit pthread_exit terminates it.
        pthread_exit(nullptr);
    }

    auto *rt = static_cast<RenderThread *>(arg);
    rt->iter();
    loopExitTime = std::chrono::high_resolution_clock::now();
    loopExitTimeValid = true;
}

static void *startHelper(void * parm) {
    loopStart = std::chrono::high_resolution_clock::now();
    RenderThread::mLiveWorkerCount.fetch_add(1, std::memory_order_relaxed);
    emscripten_set_main_loop_arg(&mainLoop, parm, 0, true);
    return nullptr;
}

#endif

RenderThread::RenderThread()
{
    srand(time(NULL));
    _lastFrameTime = std::chrono::high_resolution_clock::now();
    // Reset the static stop flag so the new worker doesn't immediately exit
    // if the previous cycle left it true. On web the caller must have waited
    // for mLiveWorkerCount to hit 0 before getting here, otherwise the previous
    // worker can observe this reset and miss its stop signal.
    mStop.store(false);
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
    // pthread_join from the browser main thread is fundamentally restricted in
    // Emscripten: it would have to call Atomics.wait, which the Web platform
    // disallows on the main thread (would freeze the event loop). With
    // ALLOW_BLOCKING_ON_MAIN_THREAD=1 emscripten downgrades it to a busy-spin
    // warning, but in practice it hangs the page indefinitely.
    //
    // Detach instead. The worker has been signalled via mStop; on its next
    // iteration mainLoop will call emscripten_cancel_main_loop +
    // mi_thread_done + pthread_exit, terminating the pthread cleanly. Detach
    // hands the OS responsibility for reaping it so the destructor can return
    // without blocking. Callers that need to wait for the worker to actually
    // finish exiting (e.g. before constructing a replacement RenderThread)
    // should poll mLiveWorkerCount from Dart.
    pthread_detach(t);
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
