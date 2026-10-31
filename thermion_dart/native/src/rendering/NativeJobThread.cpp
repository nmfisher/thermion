#include "rendering/NativeJobThread.hpp"
#include "Log.hpp"
#include <cstdlib>
#include <ctime>

namespace thermion {

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
        task();
        taskLock.lock();
    }
}

} // namespace thermion
