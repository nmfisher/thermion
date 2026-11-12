#pragma once

#include <deque>
#include <functional>
#include <future>
#include <memory>
#include <mutex>
#include <utility>

namespace thermion {

// Shared job submission and queue storage. Each platform controls scheduling,
// its stop flag and worker destruction. Concrete workers are final so their
// virtual hooks stay fixed during worker startup and shutdown.
class JobThreadBase {
public:
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

    /// Submits work that destroys or detaches objects the render loop may be
    /// using (engine, renderer, swapchains, views, animation managers).
    /// Platforms that can drain pending work synchronously with an in-flight
    /// animation callback (the web worker's pre-render drain) keep this work
    /// out of that drain; everywhere else it behaves exactly like
    /// [addDetachedTask].
    template <class Rt>
    auto addLifecycleTask(std::packaged_task<Rt()>& task) -> std::future<Rt> {
        auto result = task.get_future();
        addDetachedLifecycleTask([task = std::make_shared<std::packaged_task<Rt()>>(std::move(task))] {
            (*task)();
        });
        return result;
    }

    template <class Fn>
    void addDetachedLifecycleTask(Fn&& fn) {
        enqueueLifecycle(std::function<void()>(std::forward<Fn>(fn)));
    }

    virtual bool isStopping() const = 0;

protected:
    // Own the concrete type. Web destroy() must drain work before deletion.
    virtual ~JobThreadBase() = default;
    virtual void enqueue(std::function<void()> task) = 0;
    // Single-queue workers run lifecycle work through the normal queue.
    virtual void enqueueLifecycle(std::function<void()> task) {
        enqueue(std::move(task));
    }

    std::mutex _taskMutex;
    std::deque<std::function<void()>> _tasks;
};

} // namespace thermion
