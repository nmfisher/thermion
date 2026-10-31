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

    virtual bool isStopping() const = 0;

protected:
    // Own the concrete type. Web destroy() must drain work before deletion.
    virtual ~JobThreadBase() = default;
    virtual void enqueue(std::function<void()> task) = 0;

    std::mutex _taskMutex;
    std::deque<std::function<void()>> _tasks;
};

} // namespace thermion
