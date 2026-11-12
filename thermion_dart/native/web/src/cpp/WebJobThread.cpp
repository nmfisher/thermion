#include "rendering/WebJobThread.hpp"
#include "Log.hpp"
#include <cassert>
#include <cstdlib>
#include <emscripten/emscripten.h>
#include <emscripten/proxying.h>
#include <emscripten/eventloop.h>
#include <mimalloc.h>

namespace thermion {

// Per-pump drain budget in milliseconds. Long enough to keep a whole
// single-frame scene update (a camera plus a handful of transforms) atomic
// with respect to rendering, short enough to keep yielding to browser events
// (Filament driver callbacks, proxy deliveries) under sustained load.
constexpr double kDrainBudgetMs = 2.0;

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

void WebJobThread::enqueueLifecycle(std::function<void()> work) {
#ifdef THERMION_WEB_MAIN_THREAD
    CurrentThreadScope current(*this);
    work();
    runAfterBatchCallback();
#else
    std::unique_lock<std::mutex> lock(_taskMutex);
    if (isStopping() && !isWorkerThread()) {
        lock.unlock();
        Log("Cannot submit work after JobThread shutdown");
        std::abort();
    }
    // Lifecycle tasks run only from pumpTasks. The pre-render drain skips
    // them so it can never free objects an animation callback is using.
    _lifecycleTasks.push_back(std::move(work));
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
    // Drain under a time budget instead of the old fixed 8-task cap, then
    // yield to browser events with a zero-timeout continuation. The fixed cap
    // could split a multi-call scene update across animation frames; the
    // budget keeps long streams from starving the worker event loop instead.
    // Lifecycle tasks always follow ordinary ones: destruction work delayed
    // past later state updates is safe (everything it touches is still
    // alive), while the reverse order is not.
    std::unique_lock<std::mutex> lock(_taskMutex);
    const double drainStartMs = emscripten_get_now();
    while (!_tasks.empty()) {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        lock.unlock();
        task();
        task = {};
        lock.lock();
        if (emscripten_get_now() - drainStartMs > kDrainBudgetMs) break;
    }
    while (!_lifecycleTasks.empty()) {
        auto task = std::move(_lifecycleTasks.front());
        _lifecycleTasks.pop_front();
        lock.unlock();
        task();
        task = {};
        lock.lock();
        if (emscripten_get_now() - drainStartMs > kDrainBudgetMs) break;
    }
    // Run the installed backend flush even when no drawing callback arrives.
    lock.unlock();
    runAfterBatchCallback();
    lock.lock();
    if (!_tasks.empty() || !_lifecycleTasks.empty()) {
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

void WebJobThread::drainPendingTasks() {
    // Pre-render drain: apply every ordinary task queued so far so a frame
    // never renders a partially-updated scene. Runs on this worker's thread
    // from RenderManager::onAnimationFrame; pumps and animation callbacks
    // never nest on one thread, so this cannot re-enter itself. A wakeup that
    // was already scheduled still fires afterwards and no-ops on the drained
    // queue. Lifecycle tasks deliberately stay queued for pumpTasks. In
    // THERMION_WEB_MAIN_THREAD mode commands execute inline, so this is a
    // no-op there.
    CurrentThreadScope current(*this);
    std::unique_lock<std::mutex> lock(_taskMutex);
    while (!_tasks.empty()) {
        auto task = std::move(_tasks.front());
        _tasks.pop_front();
        lock.unlock();
        task();
        task = {};
        lock.lock();
    }
    if (!isStopping()) {
        _wakePending = false;
    }
}

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
