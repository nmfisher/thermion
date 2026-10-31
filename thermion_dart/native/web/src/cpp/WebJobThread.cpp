#include "rendering/WebJobThread.hpp"
#include "Log.hpp"
#include <chrono>
#include <cstdlib>
#include <ctime>
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#include <mimalloc.h>

namespace thermion {

std::atomic<int32_t> WebJobThread::mLiveWorkerCount{0};
thread_local WebJobThread* WebJobThread::_current = nullptr;

class WebJobThread::CurrentThreadScope {
public:
    explicit CurrentThreadScope(WebJobThread& thread)
        : _previous(std::exchange(_current, &thread)) {}
    ~CurrentThreadScope() { _current = _previous; }

private:
    WebJobThread* _previous;
};

const char* WebJobThread::currentCanvasSelector() {
    return _current ? _current->_canvasSelector.c_str() : nullptr;
}

// A callback must remain deliverable after its JobThread is destroyed.
// Keep this queue until the Wasm module is unloaded.
static emscripten::ProxyingQueue& callbacks() {
    static auto* queue = new emscripten::ProxyingQueue();
    return *queue;
}
void WebJobThread::dispatchCallback(std::function<void()> callback) const {
#ifdef THERMION_WEB_MAIN_THREAD
    callback();
#else
    if (!callbacks().proxyAsync(outer, std::move(callback))) {
        Log("Failed to post render completion");
        std::abort();
    }
#endif
}

void WebJobThread::executeCallbacks() { callbacks().execute(); }


#ifndef THERMION_WEB_MAIN_THREAD
std::chrono::high_resolution_clock::time_point loopStart;
std::chrono::high_resolution_clock::time_point loopExitTime;
bool loopExitTimeValid = false;

// Heap arg for the worker: owns a shared_ptr copy of the stop flag so the
// flag outlives the JobThread (web detach lets the destructor return
// before the worker's next iteration). The worker frees this struct itself
// on exit — the destructor never touches it.
struct WorkerArg {
    WebJobThread *rt;
    std::shared_ptr<WebJobThread::StopFlag> stop;
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
        WebJobThread::mLiveWorkerCount.fetch_sub(1, std::memory_order_relaxed);
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
    WebJobThread::mLiveWorkerCount.fetch_add(1, std::memory_order_relaxed);
    emscripten_set_main_loop_arg(&mainLoop, parm, 0, true);
    return nullptr;
}

#endif

std::unique_ptr<WebJobThread> WebJobThread::create(const char* canvasSelector) {
    auto thread = std::make_unique<WebJobThread>(canvasSelector);
    if (thread->_creationFailed) return nullptr;
    return thread;
}

void WebJobThread::destroy(std::unique_ptr<WebJobThread> thread) {
    thread.reset();
}

WebJobThread::WebJobThread(const char* canvasSelector)
    : _canvasSelector(canvasSelector ? canvasSelector : "#thermion_canvas") {
    srand(time(nullptr));
    Log("Starting JobThread")
    outer = pthread_self();
#ifndef THERMION_WEB_MAIN_THREAD
    startWorker(canvasSelector);
#endif
}

#ifndef THERMION_WEB_MAIN_THREAD
void WebJobThread::startWorker(const char* canvasSelector) {
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

WebJobThread::~WebJobThread()
{
    size_t pendingTaskCount;
    {
        std::lock_guard<std::mutex> lock(_taskMutex);
        pendingTaskCount = _tasks.size();
    }
    TRACE("Destroying JobThread (%zu tasks remaining)", pendingTaskCount);
    shutdown();
    CurrentThreadScope current(*this);

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

    TRACE("JobThread destructor complete");
}

void WebJobThread::shutdown() {
    _stop->value.store(true, std::memory_order_release);
}

void WebJobThread::enqueue(std::function<void()> task) {
#ifdef THERMION_WEB_MAIN_THREAD
    CurrentThreadScope current(*this);
    task();
    runAfterBatchCallback();
#else
    std::lock_guard<std::mutex> lock(_taskMutex);
    _tasks.push_back(std::move(task));
#endif
}

void WebJobThread::pumpTasks() {
    CurrentThreadScope current(*this);
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

void WebJobThread::runAfterBatchCallback() {
    // A callback may clear the installed hook through a nested command.
    auto callback = _afterBatch;
    if (callback) callback();
}

void WebJobThread::iter() {
    pumpTasks();
}

} // namespace thermion
