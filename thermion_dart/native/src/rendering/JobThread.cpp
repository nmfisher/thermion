#include "rendering/JobThread.hpp"
// Web only: iter() calls into RenderManager. The native worker never touches
// the manager, so the standalone queue test can compile this file without
// Filament headers.
#ifdef __EMSCRIPTEN__
#include "rendering/RenderManager.hpp"
#endif

#include <functional>
#include <stdlib.h>
#include <time.h>
#include <chrono>

#include "Log.hpp"

namespace thermion {

std::atomic<int32_t> JobThread::mLiveWorkerCount{0};

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

#ifndef THERMION_WEB_MAIN_THREAD
std::chrono::high_resolution_clock::time_point loopStart;
std::chrono::high_resolution_clock::time_point loopExitTime;
bool loopExitTimeValid = false;

// Heap arg for the worker: owns a shared_ptr copy of the stop flag so the
// flag outlives the JobThread (web detach lets the destructor return
// before the worker's next iteration). The worker frees this struct itself
// on exit — the destructor never touches it.
struct WorkerArg {
    JobThread *rt;
    std::shared_ptr<JobThread::StopFlag> stop;
};

static void mainLoop(void* arg) {
    // Check the stop flag BEFORE touching `rt` — the destructor may have
    // returned (via pthread_detach) and `*this` may already be freed. The
    // flag is heap-shared, so the read is safe; the worker never dereferences
    // the JobThread after observing stop.
    auto *workerArg = static_cast<WorkerArg *>(arg);
    if (workerArg->stop->value.load()) {
        emscripten_cancel_main_loop();
        loopExitTime = std::chrono::high_resolution_clock::now();
        loopExitTimeValid = true;
        // mimalloc reserves a per-thread arena (~32 MiB initial on wasm32)
        // that survives pthread_exit unless we explicitly release it.
        mi_thread_done();
        JobThread::mLiveWorkerCount.fetch_sub(1, std::memory_order_relaxed);
        // emscripten_set_main_loop_arg(..., simulate_infinite_loop=true) threw
        // to unwind startHelper, so the pthread function never returned. The
        // JS-side worker would otherwise stay alive in the event loop after
        // emscripten_cancel_main_loop; explicit pthread_exit terminates it.
        delete workerArg;
        pthread_exit(nullptr);
    }

    auto *rt = workerArg->rt;
    rt->iter();
    loopExitTime = std::chrono::high_resolution_clock::now();
    loopExitTimeValid = true;
}

static void *startHelper(void * parm) {
    loopStart = std::chrono::high_resolution_clock::now();
    JobThread::mLiveWorkerCount.fetch_add(1, std::memory_order_relaxed);
    emscripten_set_main_loop_arg(&mainLoop, parm, 0, true);
    return nullptr;
}

#endif
#endif

JobThread::JobThread(const char* canvasSelector)
    : _canvasSelector(canvasSelector != nullptr ? canvasSelector : "#thermion_canvas")
{
    srand(time(NULL));
    #ifdef __EMSCRIPTEN__
    Log("Starting JobThread")
    outer = pthread_self();
#ifndef THERMION_WEB_MAIN_THREAD
    startWebWorker(canvasSelector);
#endif
    #else
    _thread = new std::thread([this]() { runNativeLoop(); });
    #endif
}

#if defined(__EMSCRIPTEN__) && !defined(THERMION_WEB_MAIN_THREAD)
// Start the worker pthread and transfer the canvas to it. On failure,
// _creationFailed lets the C API return a null handle instead of a worker
// that would hang every queued task forever.
void JobThread::startWebWorker(const char* canvasSelector) {
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    emscripten_pthread_attr_settransferredcanvases(&attr, canvasSelector);
    auto *workerArg = new WorkerArg{this, _stop};
    int rc = pthread_create(&_thread, &attr, startHelper, workerArg);
    if (rc != 0) {
      Log("SEVERE - pthread_create failed with code %d; worker did not start "
          "(canvas selector %s, pool exhausted?)",
          rc, canvasSelector);
      _creationFailed = true;
      delete workerArg;
    }
}
#endif

JobThread::~JobThread()
{
    size_t pendingTaskCount;
    {
        std::lock_guard<std::mutex> lock(_taskMutex);
        pendingTaskCount = _tasks.size();
    }
    TRACE("Destroying JobThread (%zu tasks remaining)", pendingTaskCount);
    shutdown();

    #ifdef __EMSCRIPTEN__
    // The web worker cannot be synchronously joined from the browser main
    // thread. Preserve the existing synchronous drain behavior, but claim
    // each task under the queue mutex so the worker and destructor cannot
    // concurrently mutate the deque.
    while (true) {
        std::function<void()> task;
        {
            std::lock_guard<std::mutex> lock(_taskMutex);
            if (_tasks.empty()) {
                break;
            }
            task = std::move(_tasks.front());
            _tasks.pop_front();
        }
        task();
    }

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
    // finish exiting (e.g. before constructing a replacement JobThread)
    // should poll mLiveWorkerCount from Dart.
#ifndef THERMION_WEB_MAIN_THREAD
    pthread_detach(_thread);
#endif
    #else
    TRACE("Joining JobThread thread..");
    _thread->join();
    delete _thread;
    #endif

    TRACE("JobThread destructor complete");
}

void JobThread::shutdown()
{
    _stop->value.store(true, std::memory_order_release);
    #ifndef __EMSCRIPTEN__
    _cv.notify_all();
    #endif
}

void JobThread::enqueue(std::function<void()> task) {
#if defined(__EMSCRIPTEN__) && defined(THERMION_WEB_MAIN_THREAD)
    task();
    flushCommands();
#else
    {
        std::lock_guard<std::mutex> lock(_taskMutex);
        _tasks.push_back(std::move(task));
    }
    #ifndef __EMSCRIPTEN__
    _cv.notify_one();
    #endif
#endif
}

#ifdef __EMSCRIPTEN__
// Bound each batch so uploads reach tick() and its command-buffer drain even
// when completions keep queuing more work. Filament calls stay on the worker;
// the queue mutex is released while each task executes.
void JobThread::pumpTasks() {
    std::unique_lock<std::mutex> taskLock(_taskMutex);

    unsigned taskCount = 0;
    while (!_tasks.empty() && taskCount++ < 8)
    {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        taskLock.unlock();
        task();
        taskLock.lock();
    }
    taskLock.unlock();
}

void JobThread::flushCommands() {
    if (_renderManager) _renderManager->flushCommands();
}

void JobThread::iter() {
    // FPS measurement
    auto now = std::chrono::high_resolution_clock::now();

    pumpTasks();

    // Render at most one swapchain per rAF so Filament's WebGL backend can
    // commit the frame between iterations. When no render has been requested,
    // tick() is a cheap flag-check and returns immediately.
    if (_renderManager) {
        auto frameTimeInNanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                                    now.time_since_epoch()).count();
        _renderManager->tick(frameTimeInNanos);
    }
}
#else
void JobThread::runNativeLoop() {
    std::unique_lock<std::mutex> taskLock(_taskMutex);

    while (true) {
        _cv.wait(taskLock, [this] {
            return !_tasks.empty() || isStopping();
        });

        if (_tasks.empty()) {
            // A stop request only terminates the worker after it has executed
            // every task that was already queued.
            if (isStopping()) {
                break;
            }
            continue;
        }

        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        taskLock.unlock();
        task();
        taskLock.lock();
    }
}
#endif

} // namespace thermion
