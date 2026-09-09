#pragma once
#include <cstdint>
#include <memory>

namespace thermion {

// A dispatch scope belongs to the calling native thread. Dart installs it only
// around a synchronous FFI call and clears it before awaiting its completion.
struct TaskErrorContext {
    using Callback = void (*)(uint32_t requestId, const char* ownedMessage);
    uint32_t requestId = 0;
    Callback callback = nullptr;
    std::shared_ptr<const TaskErrorContext> parent;
};

inline thread_local TaskErrorContext currentTaskError;

inline void pushTaskErrorContext(uint32_t requestId, TaskErrorContext::Callback callback) {
    auto parent = currentTaskError.callback
        ? std::make_shared<TaskErrorContext>(currentTaskError) : nullptr;
    currentTaskError = {requestId, callback, std::move(parent)};
}

inline void popTaskErrorContext() {
    currentTaskError = currentTaskError.parent ? *currentTaskError.parent : TaskErrorContext{};
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
