#pragma once

#include <atomic>
#include <cstdint>

namespace thermion {

// Counts release notifications only. It never owns or deletes upload data.
// The initial token covers submission itself, so an early buffer completion
// cannot fire the callback while later mip levels are still being submitted.
class UploadCompletion {
public:
    using Callback = void (*)(int32_t);
    UploadCompletion(Callback callback, uint32_t requestId)
        : _callback(callback), _requestId(requestId) {}

    void addBuffer() noexcept { _pending.fetch_add(1, std::memory_order_relaxed); }

    // Called once per descriptor release, and once when submission ends,
    // including when submission throws. No token is added for unsubmitted mips.
    void release() noexcept {
        if (_pending.fetch_sub(1, std::memory_order_acq_rel) != 1) return;
        const auto callback = _callback;
        const auto requestId = _requestId;
        delete this;
        if (callback) callback(requestId);
    }

private:
    ~UploadCompletion() = default;
    std::atomic<uint32_t> _pending{1};
    Callback _callback;
    uint32_t _requestId;
};

} // namespace thermion
