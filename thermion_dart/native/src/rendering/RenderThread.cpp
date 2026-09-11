#include "rendering/RenderThread.hpp"
#ifdef __EMSCRIPTEN__
#include "rendering/RenderManager.hpp"
#endif
#include "Log.hpp"

#include <cassert>
#include <cstdlib>
#include <cstring>
#include <chrono>

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#include <mimalloc.h>
#endif

namespace thermion {

std::atomic<int32_t> RenderThread::mLiveWorkerCount{0};

#ifdef __EMSCRIPTEN__
// The queues live until the WASM module is unloaded. A completion posted to the
// browser must survive destruction of its originating RenderThread. Wakeups
// share the same lifetime so executing proxy closures never own a dying queue.
static emscripten::ProxyingQueue& callbacks() {
    static auto* queue = new emscripten::ProxyingQueue();
    return *queue;
}
static emscripten::ProxyingQueue& wakeups() {
    static auto* queue = new emscripten::ProxyingQueue();
    return *queue;
}

#endif

RenderThread::RenderThread(const char* canvasSelector)
    : _canvasSelector(canvasSelector ? canvasSelector : "#thermion_canvas") {
#ifdef __EMSCRIPTEN__
    _caller = pthread_self();
    startWebWorker();
#else
    _thread = std::thread([this] { runNativeLoop(); });
#endif
}

RenderThread::~RenderThread() {
#ifdef __EMSCRIPTEN__
    assert(_creationFailed || _workerFinished);
#else
    shutdown();
    _thread.join();
#endif
}

bool RenderThread::isWorkerThread() const {
#ifdef __EMSCRIPTEN__
    return pthread_equal(pthread_self(), _thread);
#else
    return std::this_thread::get_id() == _thread.get_id();
#endif
}

void RenderThread::shutdown() {
    {
        std::lock_guard<std::mutex> lock(_taskMutex);
        _stopping.store(true, std::memory_order_release);
#ifdef __EMSCRIPTEN__
        if (!_creationFailed) scheduleWakeLocked();
#endif
    }
#ifndef __EMSCRIPTEN__
    _cv.notify_one();
#endif
}

void RenderThread::enqueue(std::function<void()> work) {
    {
        std::unique_lock<std::mutex> lock(_taskMutex);
        // Accepted tasks can enqueue their own completion work while draining.
        if (isStopping() && !isWorkerThread()) {
            lock.unlock();
            Log("Cannot submit work after RenderThread shutdown");
            std::abort();
        }
        _tasks.push_back(std::move(work));
#ifdef __EMSCRIPTEN__
        scheduleWakeLocked();
#endif
    }
#ifndef __EMSCRIPTEN__
    _cv.notify_one();
#endif
}

#ifdef __EMSCRIPTEN__
void RenderThread::startWebWorker() {
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    emscripten_pthread_attr_settransferredcanvases(&attr, _canvasSelector.c_str());
    // Include workers that have been requested but not entered startHelper yet.
    mLiveWorkerCount.fetch_add(1, std::memory_order_relaxed);
    const int result = pthread_create(&_thread, &attr, startHelper, this);
    pthread_attr_destroy(&attr);
    if (result != 0) {
        _creationFailed = true;
        mLiveWorkerCount.fetch_sub(1, std::memory_order_relaxed);
        Log("RenderThread pthread_create failed: %d", result);
    }
}

void* RenderThread::startHelper(void* arg) {
    // simulateInfiniteLoop keeps this pthread's event loop alive for wakeups.
    emscripten_set_main_loop_arg(frameCallback, arg, 0, true);
    return nullptr;
}

void RenderThread::frameCallback(void* arg) {
    auto* self = static_cast<RenderThread*>(arg);
    if (self->isStopping()) return;
    if (self->_renderManager) {
        const auto now = std::chrono::steady_clock::now();
        self->_renderManager->tick(std::chrono::duration_cast<std::chrono::nanoseconds>(
            now.time_since_epoch()).count());
    }
}

void RenderThread::scheduleWakeLocked() {
    if (_wakePending) return;
    _wakePending = true;
    // Coalesce notifications. Shutdown deletes this object only after the
    // pump and its continuations have finished on this worker.
    if (!wakeups().proxyAsync(_thread, [this] { pumpTasks(); })) {
        _wakePending = false;
        Log("Failed to wake render worker");
        std::abort();
    }
}

void RenderThread::pumpCallback(void* arg) {
    auto* self = static_cast<RenderThread*>(arg);
    self->pumpTasks();
}

void RenderThread::pumpTasks() {
    // Check between tasks: one expensive task or backend execution can exceed
    // this budget. It is a yielding policy, not a hard two-millisecond deadline.
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(2);
    std::unique_lock<std::mutex> lock(_taskMutex);
    while (!_tasks.empty()) {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        lock.unlock();
        task();
        task = {};
        lock.lock();
        if (std::chrono::steady_clock::now() >= deadline) break;
    }
    // Browser backgrounding can suspend rAF entirely. Commands from uploads
    // and other API calls still need to reach Filament's single-thread backend.
    lock.unlock();
    if (_renderManager) _renderManager->executePendingCommands();
    lock.lock();
    if (!_tasks.empty()) {
        // A timer continuation yields the worker event loop; re-proxying onto
        // the currently executing queue could otherwise drain without yielding.
        emscripten_set_timeout(pumpCallback, 0, this);
    } else if (isStopping()) {
        // Exit outside the proxy callback so its closure is freed first.
        emscripten_set_timeout(finishShutdown, 0, this);
    } else {
        _wakePending = false;
    }
}

void RenderThread::finishShutdown(void* arg) {
    auto* self = static_cast<RenderThread*>(arg);
    emscripten_cancel_main_loop();
    self->_workerFinished = true;
    delete self; // ownership transferred by shutdown(), after registry release
    mi_thread_done();
    mLiveWorkerCount.fetch_sub(1, std::memory_order_relaxed);
    pthread_exit(nullptr);
}

void RenderThread::dispatchCallback(std::function<void()> callback) const {
    if (!callbacks().proxyAsync(_caller, std::move(callback))) {
        Log("Failed to post render completion");
        std::abort();
    }
}

void RenderThread::executeCallbacks() { callbacks().execute(); }

void RenderThread::setRenderManager(RenderManager* manager) {
    assert(isWorkerThread());
    _renderManager = manager;
}
#else
void RenderThread::runNativeLoop() {
    std::unique_lock<std::mutex> lock(_taskMutex);
    while (true) {
        _cv.wait(lock, [this] { return !_tasks.empty() || isStopping(); });
        if (_tasks.empty() && isStopping()) return;
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        lock.unlock();
        task();
        task = {};
        lock.lock();
    }
}
#endif

} // namespace thermion
