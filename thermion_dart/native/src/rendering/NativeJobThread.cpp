#include "rendering/NativeJobThread.hpp"
#include "rendering/EngineApiLock.hpp"
#include "Log.hpp"
#include <cstdlib>
#include <ctime>
#include <chrono>
#include <thread>
#include <vector>
#include <functional>

namespace thermion {

std::recursive_mutex& engineApiMutex() {
    // Leaked on purpose: never destroyed, so nothing runs at DLL unload.
    static std::recursive_mutex* m = new std::recursive_mutex();
    return *m;
}

std::atomic<int>& engineApiWaiters() {
    static std::atomic<int>* w = new std::atomic<int>(0);
    return *w;
}

// Dart completions queued by the task currently running on this job thread.
static thread_local std::vector<std::function<void()>>* tDeferredDartCallbacks = nullptr;

void deferDartCallback(std::function<void()> fn) {
    if (tDeferredDartCallbacks) {
        tDeferredDartCallbacks->push_back(std::move(fn));
    } else {
        fn();
    }
}

// Let direct callers that are already waiting take the lock before the next
// task. Yield first; back off to short sleeps if a caller holds it for long.
static void yieldToDirectCallers() {
    for (int spins = 0; engineApiWaiters().load(std::memory_order_acquire) > 0; ++spins) {
        if (spins < 64) {
            std::this_thread::yield();
        } else {
            std::this_thread::sleep_for(std::chrono::microseconds(50));
        }
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
    _stopping.store(true, std::memory_order_release);
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
        std::vector<std::function<void()>> dartCallbacks;
        {
            // Serialise with the direct (non-JobThread) C exports called from
            // other threads (see EngineApiLock.hpp). Held per task, never
            // while waiting for work, and never while calling into Dart.
            yieldToDirectCallers();
            std::lock_guard<std::recursive_mutex> engineLock(engineApiMutex());
            tDeferredDartCallbacks = &dartCallbacks;
            task();
            tDeferredDartCallbacks = nullptr;
        }
        for (auto& callback : dartCallbacks) {
            callback();
        }
        taskLock.lock();
    }
}

} // namespace thermion
