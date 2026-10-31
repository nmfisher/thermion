#pragma once

#include <atomic>
#include <cstdint>
#include <deque>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <emscripten/threading.h>

namespace thermion {

class RenderManager;

// Web commands are polled in batches of eight on browser animation frames.
// Destruction still drains on the caller and stops the worker asynchronously.
// The worker lifecycle fix is separate from this platform split.
// THERMION_WEB_MAIN_THREAD executes commands inline without starting a worker.
class WebJobThread {
public:
    explicit WebJobThread(const char* canvasSelector);
    ~WebJobThread();

    static std::unique_ptr<WebJobThread> create(const char* canvasSelector = "#thermion_canvas");
    static void destroy(std::unique_ptr<WebJobThread> thread);

    template <class Rt>
    auto addTask(std::packaged_task<Rt()>& task) -> std::future<Rt> {
        auto result = task.get_future();
        addDetachedTask([task = std::make_shared<std::packaged_task<Rt()>>(std::move(task))] {
            (*task)();
        });
        return result;
    }

    template <class Fn>
    void addDetachedTask(Fn&& fn) {
        enqueue(std::function<void()>(std::forward<Fn>(fn)));
    }

    bool isStopping() const { return _stop->value.load(std::memory_order_acquire); }
    const char* canvasSelector() const { return _canvasSelector.c_str(); }
    void dispatchCallback(std::function<void()> callback) const;
    static void executeCallbacks();
    void setRenderManager(RenderManager* manager) { _renderManager = manager; }
    void iter();
    static std::atomic<int32_t> mLiveWorkerCount;

    // The legacy worker loop checks this flag after destruction returns.
    struct StopFlag { std::atomic<bool> value{false}; };
    std::shared_ptr<StopFlag> stopFlag() const { return _stop; }

private:
    void shutdown();
    void startWorker(const char* canvasSelector);
    void enqueue(std::function<void()> task);
    void pumpTasks();
    void flushCommands();

    std::mutex _taskMutex;
    std::deque<std::function<void()>> _tasks;
    std::shared_ptr<StopFlag> _stop = std::make_shared<StopFlag>();
    // Dart frees its UTF8 buffer immediately after worker creation.
    std::string _canvasSelector;
    bool _creationFailed = false;
    pthread_t _thread{};
    pthread_t outer{};
    RenderManager* _renderManager = nullptr;
};

} // namespace thermion
