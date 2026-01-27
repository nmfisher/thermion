#pragma once

#include <atomic>
#include <thread>
#include <chrono>

namespace thermion {

class FrameScheduler {
public:
    using Callback = void (*)(uint64_t frameTimeNanos);

    virtual ~FrameScheduler() = default;
    virtual void start(Callback callback) = 0;
    virtual void stop() = 0;
};

/// Timer-based fallback (Windows, Linux, Android, etc.).
class TimerFrameScheduler : public FrameScheduler {
    std::thread* _thread = nullptr;
    std::atomic<bool> _running{false};
    int _targetFps;
public:
    explicit TimerFrameScheduler(int targetFps) : _targetFps(targetFps) {}
    ~TimerFrameScheduler() override { stop(); }
    void start(Callback callback) override;
    void stop() override;
};

} // namespace thermion
