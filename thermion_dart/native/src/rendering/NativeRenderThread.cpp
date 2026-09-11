#include "rendering/NativeRenderThread.hpp"
#include "Log.hpp"
#include <cstdlib>

namespace thermion {

std::unique_ptr<NativeRenderThread> NativeRenderThread::create(const char*) {
    return std::make_unique<NativeRenderThread>();
}

void NativeRenderThread::destroy(std::unique_ptr<NativeRenderThread> thread) {
    thread.reset();
}

NativeRenderThread::NativeRenderThread()
    : _thread([this] { run(); }) {}

NativeRenderThread::~NativeRenderThread() {
    {
        std::lock_guard<std::mutex> lock(_taskMutex);
        _stopping.store(true, std::memory_order_release);
    }
    _cv.notify_one();
    _thread.join();
}

void NativeRenderThread::enqueue(std::function<void()> work) {
    {
        std::unique_lock<std::mutex> lock(_taskMutex);
        // Accepted work can enqueue its own completion while draining.
        if (isStopping() && std::this_thread::get_id() != _thread.get_id()) {
            lock.unlock();
            Log("Cannot submit work after RenderThread shutdown");
            std::abort();
        }
        _tasks.push_back(std::move(work));
    }
    _cv.notify_one();
}

void NativeRenderThread::run() {
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

} // namespace thermion
