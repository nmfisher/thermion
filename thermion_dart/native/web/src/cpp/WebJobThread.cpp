#include "rendering/WebJobThread.hpp"
#include "Log.hpp"
#include <cassert>
#include <cstdlib>
#include <emscripten/emscripten.h>
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

// The queues live until the WASM module is unloaded. A completion posted to the
// browser must survive destruction of its originating JobThread. Wakeups
// share the same lifetime so executing proxy closures never own a dying queue.
static emscripten::ProxyingQueue& callbacks() {
    static auto* queue = new emscripten::ProxyingQueue();
    return *queue;
}
static emscripten::ProxyingQueue& wakeups() {
    static auto* queue = new emscripten::ProxyingQueue();
    return *queue;
}


std::unique_ptr<WebJobThread> WebJobThread::create(const char* canvasSelector) {
    auto thread = std::make_unique<WebJobThread>(canvasSelector);
    if (thread->_creationFailed) return nullptr;
    return thread;
}

void WebJobThread::destroy(std::unique_ptr<WebJobThread> thread) {
#ifdef THERMION_WEB_MAIN_THREAD
    thread.reset();
#else
    // Release the caller's owner before the worker can finish and delete itself.
    if (thread) thread.release()->requestShutdown();
#endif
}

WebJobThread::WebJobThread(const char* canvasSelector)
    : _canvasSelector(canvasSelector ? canvasSelector : "#thermion_canvas") {
    _caller = pthread_self();
#ifdef THERMION_WEB_MAIN_THREAD
    _thread = _caller;
#else
    startWorker();
#endif
}

WebJobThread::~WebJobThread() {
#ifdef THERMION_WEB_MAIN_THREAD
    requestShutdown();
#else
    assert(_creationFailed || _workerFinished);
#endif
}

bool WebJobThread::isWorkerThread() const {
    return pthread_equal(pthread_self(), _thread);
}

void WebJobThread::requestShutdown() {
    // Unlocking is the final access to this object: the worker may delete it
    // as soon as it acquires the mutex and finishes draining.
    std::lock_guard<std::mutex> lock(_taskMutex);
    _stopping.store(true, std::memory_order_release);
#ifndef THERMION_WEB_MAIN_THREAD
    if (!_creationFailed) scheduleWakeLocked();
#endif
}

void WebJobThread::enqueue(std::function<void()> work) {
#ifdef THERMION_WEB_MAIN_THREAD
    CurrentThreadScope current(*this);
    work();
    runAfterBatchCallback();
#else
    std::unique_lock<std::mutex> lock(_taskMutex);
    // Accepted tasks can enqueue their own completion work while draining.
    if (isStopping() && !isWorkerThread()) {
        lock.unlock();
        Log("Cannot submit work after JobThread shutdown");
        std::abort();
    }
    _tasks.push_back(std::move(work));
    scheduleWakeLocked();
#endif
}

#if defined(__EMSCRIPTEN__) && !defined(THERMION_WEB_MAIN_THREAD)
void WebJobThread::startWorker() {
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
        Log("WebJobThread pthread_create failed: %d", result);
    }
}

void* WebJobThread::startHelper(void*) {
    // Keep the pthread event loop alive for command wakeups. Drawing has its
    // own browser callbacks, owned by RenderManager.
    emscripten_exit_with_live_runtime();
}

void WebJobThread::scheduleWakeLocked() {
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

void WebJobThread::pumpCallback(void* arg) {
    auto* self = static_cast<WebJobThread*>(arg);
    self->pumpTasks();
}

void WebJobThread::pumpTasks() {
    CurrentThreadScope current(*this);
    // Keep the existing batch limit. Yield to browser events between batches,
    // and flush Filament commands even if no animation frame arrives.
    std::unique_lock<std::mutex> lock(_taskMutex);
    unsigned taskCount = 0;
    while (!_tasks.empty() && taskCount++ < 8) {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        lock.unlock();
        task();
        task = {};
        lock.lock();
    }
    // Run the installed backend flush even when no drawing callback arrives.
    lock.unlock();
    runAfterBatchCallback();
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

void WebJobThread::finishShutdown(void* arg) {
    auto* self = static_cast<WebJobThread*>(arg);
    self->_workerFinished = true;
    delete self; // ownership transferred by destroy(), after registry release
    mi_thread_done();
    mLiveWorkerCount.fetch_sub(1, std::memory_order_relaxed);
    pthread_exit(nullptr);
}

#endif

void WebJobThread::runAfterBatchCallback() {
    // A callback may clear the installed hook through a nested command.
    auto callback = _afterBatch;
    if (callback) callback();
}

void WebJobThread::dispatchCallback(std::function<void()> callback) const {
#ifdef THERMION_WEB_MAIN_THREAD
    callback();
#else
    if (!callbacks().proxyAsync(_caller, std::move(callback))) {
        Log("Failed to post render completion");
        std::abort();
    }
#endif
}

void WebJobThread::executeCallbacks() { callbacks().execute(); }


} // namespace thermion
