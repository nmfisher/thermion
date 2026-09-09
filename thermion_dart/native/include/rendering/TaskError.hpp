#pragma once
#include <cstdint>
#include <memory>

namespace thermion {

// A dispatch scope belongs to the calling native thread. Dart installs it only
// around a synchronous FFI call and clears it before awaiting its completion.
// Tasks copy this context when enqueued. The parent chain describes synchronous
// nesting, not an async operation tree; Dart Futures propagate async setup errors.
struct TaskErrorContext {
    using Callback = void (*)(uint32_t requestId, const char* ownedMessage);
    uint32_t requestId = 0;
    Callback callback = nullptr;
    std::shared_ptr<const TaskErrorContext> parent;
    uint32_t queuedTasks = 0;
};

inline thread_local TaskErrorContext currentTaskError;

inline void pushTaskErrorContext(uint32_t requestId, TaskErrorContext::Callback callback) {
    auto parent = currentTaskError.callback
        ? std::make_shared<TaskErrorContext>(currentTaskError) : nullptr;
    currentTaskError = {requestId, callback, std::move(parent)};
}

inline uint32_t popTaskErrorContext() {
    const auto queued = currentTaskError.queuedTasks;
    currentTaskError = currentTaskError.parent ? *currentTaskError.parent : TaskErrorContext{};
    return queued;
}

class TaskErrorScope {
public:
    explicit TaskErrorScope(TaskErrorContext context) : _previous(currentTaskError) {
        currentTaskError = context;
    }
    ~TaskErrorScope() { currentTaskError = _previous; }
private:
    TaskErrorContext _previous;
};

} // namespace thermion
