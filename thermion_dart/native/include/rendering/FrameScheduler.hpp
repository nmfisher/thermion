#pragma once

#include <atomic>
#include <thread>
#include <chrono>

#if __APPLE__
#include <CoreVideo/CoreVideo.h>
#endif

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

#if __APPLE__
/// macOS/iOS CVDisplayLink-based scheduler for proper vsync timing.
class CVDisplayLinkScheduler : public FrameScheduler {
    CVDisplayLinkRef _displayLink = nullptr;
    Callback _callback = nullptr;
    int64_t _dartPort = 0;
    bool _usePortMode = false;
public:
    ~CVDisplayLinkScheduler() override { stop(); }
    void start(Callback callback) override;
    void startWithPort(int64_t port);
    void stop() override;
private:
    static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
        const CVTimeStamp* inNow, const CVTimeStamp* inOutputTime,
        CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* context);
};
#endif

#ifdef _WIN32
/// Windows DXGI-based scheduler for proper vsync timing.
class DXGIFrameScheduler : public FrameScheduler {
    std::thread* _thread = nullptr;
    std::atomic<bool> _running{false};
    Callback _callback = nullptr;
    int64_t _dartPort = 0;
    bool _usePortMode = false;
    int _targetFps;
public:
    explicit DXGIFrameScheduler(int targetFps) : _targetFps(targetFps) {}
    ~DXGIFrameScheduler() override { stop(); }
    void start(Callback callback) override;
    void startWithPort(int64_t port);
    void stop() override;
};
#endif

#ifdef __ANDROID__
/// Android Choreographer-based scheduler for proper vsync timing.
/// Uses AChoreographer API (NDK API level 24+) to synchronize with display refresh.
class AChoreographerFrameScheduler : public FrameScheduler {
    std::thread* _thread = nullptr;
    std::atomic<bool> _running{false};
    Callback _callback = nullptr;
    int64_t _dartPort = 0;
    bool _usePortMode = false;
    void* _looper = nullptr;  // ALooper*
    void* _choreographer = nullptr;  // AChoreographer*
public:
    ~AChoreographerFrameScheduler() override { stop(); }
    void start(Callback callback) override;
    void startWithPort(int64_t port);
    void stop() override;
private:
    void scheduleNextFrame();
    static void frameCallback(long frameTimeNanos, void* data);
};
#endif

} // namespace thermion
