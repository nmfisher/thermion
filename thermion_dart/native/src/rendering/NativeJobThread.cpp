#include "rendering/NativeJobThread.hpp"
#include "rendering/EngineApiLock.hpp"
#include "Log.hpp"
#include <cassert>
#include <cstdlib>
#include <ctime>
#include <chrono>
#include <thread>
#include <vector>
#include <functional>

namespace thermion {

EngineApiMutex& engineApiMutex() {
    // Leaked on purpose: never destroyed, so nothing runs at DLL unload.
    static auto* mutex = new EngineApiMutex();
    return *mutex;
}

std::atomic<int>& engineApiWaiters() {
    static auto* waiters = new std::atomic<int>(0);
    return *waiters;
}

// Both construction and destruction run with mMutex held. The stack node is
// removed on every exit, including a throwing wait in exception-enabled builds.
EngineApiMutex::Waiter::Waiter(EngineApiMutex& owner)
    : mutex(owner), previous(owner.mLast) {
    if (previous) previous->next = this;
    else mutex.mFirst = this;
    mutex.mLast = this;
    engineApiWaiters().fetch_add(1, std::memory_order_release);
}

EngineApiMutex::Waiter::~Waiter() {
    if (previous) previous->next = next;
    else mutex.mFirst = next;
    if (next) next->previous = previous;
    else mutex.mLast = previous;
    engineApiWaiters().fetch_sub(1, std::memory_order_release);
    // If waiting threw, let the next queued caller use the idle mutex.
    if (mutex.mDepth == 0 && mutex.mFirst) mutex.mReady.notify_all();
}

void EngineApiMutex::lock() {
    std::unique_lock<std::mutex> lock(mMutex);
    const auto caller = std::this_thread::get_id();
    if (mDepth && mOwner == caller) {
        ++mDepth;
        return;
    }
    Waiter waiter(*this);
    mReady.wait(lock, [&] { return mDepth == 0 && mFirst == &waiter; });
    mOwner = caller;
    mDepth = 1;
}

bool EngineApiMutex::try_lock() {
    std::unique_lock<std::mutex> lock(mMutex, std::try_to_lock);
    if (!lock.owns_lock()) return false;
    const auto caller = std::this_thread::get_id();
    if (mDepth && mOwner == caller) {
        ++mDepth;
        return true;
    }
    if (mDepth || mFirst) return false;
    mOwner = caller;
    mDepth = 1;
    return true;
}

void EngineApiMutex::unlock() {
    bool notify;
    {
        std::lock_guard<std::mutex> lock(mMutex);
        assert(mDepth && mOwner == std::this_thread::get_id());
        notify = --mDepth == 0 && mFirst != nullptr;
        if (mDepth == 0) mOwner = std::thread::id{};
    }
    if (notify) mReady.notify_all();
}

// The outermost guard owns this thread's completion queue. Never publish this
// pointer to another thread: a callback there uses its own thread-local scope.
static thread_local std::vector<std::function<void()>>* tDeferredDartCallbacks = nullptr;

EngineApiGuard::EngineApiGuard() {
    const bool outer = (tDeferredDartCallbacks == nullptr);
    engineApiMutex().lock();
    mPreviousDartCallbacks = tDeferredDartCallbacks;
    if (outer) {
        tDeferredDartCallbacks = &mDartCallbacks;
    }
}

EngineApiGuard::~EngineApiGuard() {
    if (!mPreviousDartCallbacks) {
        // Clear before delivery so a callback cannot append to the vector being
        // iterated. Destruction also restores the scope during stack unwinding.
        tDeferredDartCallbacks = nullptr;
    }
    engineApiMutex().unlock();
    if (!mPreviousDartCallbacks) {
        for (auto& callback : mDartCallbacks) {
            callback();
        }
    }
}

void deferDartCallback(std::function<void()> fn) {
    if (tDeferredDartCallbacks) {
        tDeferredDartCallbacks->push_back(std::move(fn));
    } else {
        fn();
    }
}

std::unique_ptr<NativeJobThread> NativeJobThread::create(const char*) {
    return std::make_unique<NativeJobThread>();
}

void NativeJobThread::destroy(std::unique_ptr<NativeJobThread> thread) {
    thread.reset();
}

NativeJobThread::NativeJobThread() {
    srand(time(nullptr));
    _thread = std::thread([this] { run(); });
}

NativeJobThread::~NativeJobThread() {
    {
        // The stop predicate and wait registration must share the queue mutex.
        // Otherwise notify can arrive after a false predicate but before wait.
        std::lock_guard<std::mutex> lock(_taskMutex);
        _stopping.store(true, std::memory_order_release);
    }
    _cv.notify_all();
    _thread.join();
}

void NativeJobThread::enqueue(std::function<void()> task) {
    {
        std::lock_guard<std::mutex> lock(_taskMutex);
        _tasks.push_back(std::move(task));
    }
    _cv.notify_one();
}

void NativeJobThread::run() {
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
        {
            // Serialise with the direct (non-JobThread) C exports called from
            // other threads (see EngineApiLock.hpp). Held per task, never
            // while waiting for work, and never while calling into Dart.
            EngineApiGuard engineLock;
            task();
        }
        taskLock.lock();
    }
}

} // namespace thermion
