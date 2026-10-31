#pragma once

#include "rendering/JobThreadBase.hpp"
#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <utility>
#include <emscripten/threading.h>

namespace thermion {

// Web commands are polled in batches of eight on browser animation frames.
// Destruction still drains on the caller and stops the worker asynchronously.
// The worker lifecycle fix is separate from this platform split.
// THERMION_WEB_MAIN_THREAD executes commands inline without starting a worker.
class WebJobThread final : public JobThreadBase {
public:
    explicit WebJobThread(const char* canvasSelector);
    ~WebJobThread() override;

    static std::unique_ptr<WebJobThread> create(const char* canvasSelector = "#thermion_canvas");
    static void destroy(std::unique_ptr<WebJobThread> thread);

    bool isStopping() const override { return _stop->value.load(std::memory_order_acquire); }
    // Borrowed selector for the job running on this thread; null outside a job.
    static const char* currentCanvasSelector();
    void dispatchCallback(std::function<void()> callback) const;
    static void executeCallbacks();
    // Called on the owning thread. Clear it before destroying its captures.
    // Main-thread commands use a batch of one; worker batches are polled by iter().
    void setAfterBatchCallback(std::function<void()> callback) {
        _afterBatch = std::move(callback);
    }
    void iter();
    static std::atomic<int32_t> mLiveWorkerCount;

    // The worker checks this flag after WebJobThread is destroyed.
    struct StopFlag { std::atomic<bool> value{false}; };
    std::shared_ptr<StopFlag> stopFlag() const { return _stop; }

private:
    class CurrentThreadScope;
    static thread_local WebJobThread* _current;

    void shutdown();
    void startWorker(const char* canvasSelector);
    void enqueue(std::function<void()> task) override;
    void pumpTasks();
    void runAfterBatchCallback();

    std::shared_ptr<StopFlag> _stop = std::make_shared<StopFlag>();
    // Dart frees its UTF8 buffer immediately after worker creation.
    std::string _canvasSelector;
    bool _creationFailed = false;
    pthread_t _thread{};
    pthread_t outer{};
    std::function<void()> _afterBatch;
};

} // namespace thermion
