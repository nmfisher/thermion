#include "rendering/WebRenderThread.hpp"
#include "rendering/RenderManager.hpp"
#include "Log.hpp"
#include <cassert>
#include <chrono>
#include <cstdlib>
#include <emscripten/emscripten.h>
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#include <mimalloc.h>

namespace thermion {

std::atomic<int32_t> WebRenderThread::mLiveWorkerCount{0};

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

std::unique_ptr<WebRenderThread> WebRenderThread::create(const char* canvasSelector) {
    auto thread = std::make_unique<WebRenderThread>(canvasSelector);
    if (thread->_creationFailed) return nullptr;
    return thread;
}

void WebRenderThread::destroy(std::unique_ptr<WebRenderThread> thread) {
    // Release the caller's owner before the worker can finish and delete itself.
    if (thread) thread.release()->requestShutdown();
}

WebRenderThread::WebRenderThread(const char* canvasSelector)
    : _canvasSelector(canvasSelector ? canvasSelector : "#thermion_canvas") {
    _caller = pthread_self();
    startWorker();
}

WebRenderThread::~WebRenderThread() {
    assert(_creationFailed || _workerFinished);
}

void WebRenderThread::requestShutdown() {
    // Unlocking is the final access to this object: the worker may delete it
    // as soon as it acquires the mutex and finishes draining.
    std::lock_guard<std::mutex> lock(_taskMutex);
    _stopping.store(true, std::memory_order_release);
    scheduleWakeLocked();
}

void WebRenderThread::enqueue(std::function<void()> work) {
    std::unique_lock<std::mutex> lock(_taskMutex);
    // Accepted work can enqueue its own completion while draining.
    if (isStopping() && !pthread_equal(pthread_self(), _thread)) {
        lock.unlock();
        Log("Cannot submit work after RenderThread shutdown");
        std::abort();
    }
    _tasks.push_back(std::move(work));
    scheduleWakeLocked();
}

void WebRenderThread::startWorker() {
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

void* WebRenderThread::startHelper(void* arg) {
    // simulateInfiniteLoop keeps this pthread's event loop alive for wakeups.
    emscripten_set_main_loop_arg(frameCallback, arg, 0, true);
    return nullptr;
}

void WebRenderThread::frameCallback(void* arg) {
    auto* self = static_cast<WebRenderThread*>(arg);
    if (self->isStopping()) return;
    if (self->_renderManager) {
        const auto now = std::chrono::steady_clock::now();
        self->_renderManager->tick(std::chrono::duration_cast<std::chrono::nanoseconds>(
            now.time_since_epoch()).count());
    }
}

void WebRenderThread::scheduleWakeLocked() {
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

void WebRenderThread::pumpCallback(void* arg) {
    auto* self = static_cast<WebRenderThread*>(arg);
    self->pumpTasks();
}

void WebRenderThread::pumpTasks() {
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

void WebRenderThread::finishShutdown(void* arg) {
    auto* self = static_cast<WebRenderThread*>(arg);
    emscripten_cancel_main_loop();
    self->_workerFinished = true;
    delete self; // ownership transferred by destroy(), after registry release
    mi_thread_done();
    mLiveWorkerCount.fetch_sub(1, std::memory_order_relaxed);
    pthread_exit(nullptr);
}

void WebRenderThread::dispatchCallback(std::function<void()> callback) const {
    if (!callbacks().proxyAsync(_caller, std::move(callback))) {
        Log("Failed to post render completion");
        std::abort();
    }
}

void WebRenderThread::executeCallbacks() { callbacks().execute(); }

void WebRenderThread::setRenderManager(RenderManager* manager) {
    assert(pthread_equal(pthread_self(), _thread));
    _renderManager = manager;
}

} // namespace thermion
