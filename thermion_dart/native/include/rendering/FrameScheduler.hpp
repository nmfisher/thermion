#pragma once

#include <atomic>
#include <thread>
#include <chrono>
#include <cstdint>

#if __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#include <CoreVideo/CoreVideo.h>
#include <mach/mach_time.h>
#endif
#endif

namespace thermion {

class FrameScheduler {
public:
    using Callback = void (*)(uint64_t frameTimeNanos);

    virtual ~FrameScheduler() = default;
    virtual void start(Callback callback) = 0;
    virtual void startWithPort(int64_t port) {}
    virtual void stop() = 0;

    void setRenderThread(void* renderThread) { _renderThread = renderThread; }
    void* renderThread() const { return _renderThread; }

    static FrameScheduler* create(int targetFps);

    /// Cap the dispatch rate to [fps] by skipping frames at the source (in
    /// dispatchFrame). fps <= 0 means unlimited (dispatch every vsync).
    /// Honored by every scheduler that routes through dispatchFrame
    /// (CVDisplayLink / CADisplayLink / AChoreographer / timer / DXGI).
    void setTargetFps(int fps);

protected:
    Callback _callback = nullptr;
    int64_t _dartPort = 0;
    bool _usePortMode = false;
    void* _renderThread = nullptr;

    // Framerate-limiting state. _fpsLimit is set from another thread (Dart),
    // so it is atomic; the timing fields are only touched from the scheduler's
    // own callback thread (or after that thread has stopped).
    std::atomic<int> _fpsLimit{0};
    int _appliedFpsLimit = 0;
    uint64_t _nextDispatchNs = 0;

    void dispatchFrame(uint64_t nanos);
    void resetState();
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
    void startWithPort(int64_t port) override;
    void stop() override;
};

#if __APPLE__ && TARGET_OS_IOS
/// iOS CADisplayLink-based scheduler for proper vsync timing.
class CADisplayLinkScheduler : public FrameScheduler {
    void* _wrapper = nullptr;
public:
    ~CADisplayLinkScheduler() override { stop(); }
    void start(Callback callback) override;
    void startWithPort(int64_t port) override;
    void stop() override;
private:
    static void displayLinkCallback(uint64_t frameTimeNanos, void* context);
};
#endif // __APPLE__ && TARGET_OS_IOS

#if __APPLE__ && TARGET_OS_OSX
/// macOS CVDisplayLink-based scheduler for proper vsync timing.
class CVDisplayLinkScheduler : public FrameScheduler {
    CVDisplayLinkRef _displayLink = nullptr;
    mach_timebase_info_data_t _timebase{};
public:
    ~CVDisplayLinkScheduler() override { stop(); }
    void start(Callback callback) override;
    void startWithPort(int64_t port) override;
    void stop() override;
private:
    static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
        const CVTimeStamp* inNow, const CVTimeStamp* inOutputTime,
        CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* context);
};
#endif // __APPLE__ && TARGET_OS_OSX

#ifdef _WIN32
/// Windows DXGI-based scheduler for proper vsync timing.
class DXGIFrameScheduler : public FrameScheduler {
    std::thread* _thread = nullptr;
    std::atomic<bool> _running{false};
    int _targetFps;
public:
    explicit DXGIFrameScheduler(int targetFps) : _targetFps(targetFps) {}
    ~DXGIFrameScheduler() override { stop(); }
    void start(Callback callback) override;
    void startWithPort(int64_t port) override;
    void stop() override;
};
#endif

#ifdef __ANDROID__
/// Android Choreographer-based scheduler for proper vsync timing.
/// Uses AChoreographer API (NDK API level 24+) to synchronize with display refresh.
class AChoreographerFrameScheduler : public FrameScheduler {
    std::thread* _thread = nullptr;
    std::atomic<bool> _running{false};
    void* _looper = nullptr;  // ALooper*
    void* _choreographer = nullptr;  // AChoreographer*
public:
    ~AChoreographerFrameScheduler() override { stop(); }
    void start(Callback callback) override;
    void startWithPort(int64_t port) override;
    void stop() override;
private:
    void scheduleNextFrame();
    static void frameCallback(long frameTimeNanos, void* data);
};
#endif

} // namespace thermion
