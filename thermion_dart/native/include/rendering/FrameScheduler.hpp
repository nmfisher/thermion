#pragma once

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <thread>

#if __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#include <CoreVideo/CoreVideo.h>
#include <mach/mach_time.h>
#endif
#endif

namespace thermion {

/// Produces rate-limited callbacks from platform frame-timing sources.
///
/// A frame source is the platform mechanism that supplies timing events. The
/// source is CVDisplayLink on macOS, CADisplayLink on iOS, AChoreographer on
/// Android, DXGI vertical blanking on Windows, or an interruptible timer when
/// no platform source is available. One timing event is a source tick.
///
/// The scheduler applies the rate limit to each source tick. A tick that passes
/// the rate limit causes one callback. A rejected tick does not reach the
/// callback.
///
/// The callback runs on the source callback context. The timer, Android, and
/// Windows implementations use a scheduler-owned thread. CADisplayLink uses
/// the iOS main run loop. CVDisplayLink uses its system callback thread. The
/// callback must return quickly because it blocks that context. A slow callback
/// can delay or drop later callback delivery.
///
/// FrameScheduler only supplies timing callbacks. It does not prescribe what a
/// callback does. Callers generally use each callback to request a rendered
/// frame, but they can use it for any work that needs frame-based timing.
///
/// setTargetFps() asks supported platform sources to use the target rate. This
/// reduces wakeups. The scheduler also checks each source tick against the
/// target rate. This final check handles approximate source rates and changes
/// to the display rate. It also handles a target rate that does not divide the
/// display rate evenly.
///
/// The final check uses absolute deadlines. It skips missed deadlines and does
/// not send a burst of late callbacks. It can accept a tick up to 1 ms before a
/// deadline. This tolerance accounts for timestamp variation.
///
/// Each frame timestamp is a monotonic value in nanoseconds. The active platform
/// source selects the clock domain. Do not use the timestamp as wall-clock time.
class FrameScheduler {
public:
    /// Receives a monotonic frame timestamp and the pointer supplied to start().
    using Callback = void (*)(uint64_t frameTimeNanos, void* userData);

    virtual ~FrameScheduler() = default;

    /// Starts the frame source. Each source tick that passes rate gating invokes
    /// `callback` with its timestamp and `userData`.
    ///
    /// The scheduler does not own `userData`. The callback and `userData` must
    /// remain valid until stop() returns. Call stop() before a second start().
    virtual void start(Callback callback, void* userData = nullptr) = 0;

    /// Stops the frame source and waits for its callback context to stop.
    /// Work that the callback already posted can continue after this returns.
    virtual void stop() = 0;

    /// Creates a scheduler for the current platform.
    ///
    /// `targetFps` sets the fallback timer rate. It does not set the dispatch
    /// rate limit. Call setTargetFps() to set or change that limit. The caller
    /// owns the returned scheduler and must stop and delete it.
    static FrameScheduler* create(int targetFps);

    /// Sets the maximum callback rate. A value of zero or less removes the
    /// limit. Without a limit, each source tick causes one callback.
    ///
    /// A caller can use this method while the scheduler runs. Supported platform
    /// sources change their rate when they next schedule a tick. The scheduler
    /// enforces the limit on all platforms.
    void setTargetFps(int fps);

protected:
    Callback _callback = nullptr;
    void* _callbackUserData = nullptr;

    // setTargetFps() can change _fpsLimit from another thread. The source
    // callback owns the other timing fields while the scheduler runs.
    std::atomic<int> _fpsLimit{0};
    int _appliedFpsLimit = 0;
    uint64_t _dispatchIntervalNs = 0;
    uint64_t _nextDispatchNs = 0;

    void handleSourceTick(uint64_t timestampNanos);
    void resetState();
    virtual void onTargetFpsChanged(int) {}
};

/// Uses an interruptible timer as the frame source.
class TimerFrameScheduler : public FrameScheduler {
    std::thread* _thread = nullptr;
    std::atomic<bool> _running{false};
    int _targetFps;
    std::mutex _wakeMutex;
    std::condition_variable _wakeCondition;
public:
    explicit TimerFrameScheduler(int targetFps) : _targetFps(targetFps) {}
    ~TimerFrameScheduler() override { stop(); }
    void start(Callback callback, void* userData = nullptr) override;
    void stop() override;
private:
    void run();
    void onTargetFpsChanged(int) override;
};

#if __APPLE__ && TARGET_OS_IOS
/// Uses CADisplayLink as the iOS frame source.
class CADisplayLinkScheduler : public FrameScheduler {
    void* _wrapper = nullptr;
public:
    ~CADisplayLinkScheduler() override { stop(); }
    void start(Callback callback, void* userData = nullptr) override;
    void stop() override;
private:
    static void displayLinkCallback(uint64_t frameTimeNanos, void* context);
    void onTargetFpsChanged(int fps) override;
};
#endif // __APPLE__ && TARGET_OS_IOS

#if __APPLE__ && TARGET_OS_OSX
/// Uses CVDisplayLink as the macOS frame source.
class CVDisplayLinkScheduler : public FrameScheduler {
    CVDisplayLinkRef _displayLink = nullptr;
    mach_timebase_info_data_t _timebase{};
public:
    ~CVDisplayLinkScheduler() override { stop(); }
    void start(Callback callback, void* userData = nullptr) override;
    void stop() override;
private:
    static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
        const CVTimeStamp* inNow, const CVTimeStamp* inOutputTime,
        CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* context);
};
#endif // __APPLE__ && TARGET_OS_OSX

#ifdef _WIN32
/// Uses DXGI as the Windows frame source.
class DXGIFrameScheduler : public FrameScheduler {
    std::thread* _thread = nullptr;
    std::atomic<bool> _running{false};
    int _targetFps;
public:
    explicit DXGIFrameScheduler(int targetFps) : _targetFps(targetFps) {}
    ~DXGIFrameScheduler() override { stop(); }
    void start(Callback callback, void* userData = nullptr) override;
    void stop() override;
};
#endif

#ifdef __ANDROID__
/// Uses AChoreographer as the Android frame source.
/// Requires Android NDK API level 24 or later.
class AChoreographerFrameScheduler : public FrameScheduler {
    std::thread* _thread = nullptr;
    std::atomic<bool> _running{false};
    std::atomic<void*> _looper{nullptr};
    void* _choreographer = nullptr;
    int _sourceFps = 0;
    uint64_t _nextSourceFrameNs = 0;
public:
    ~AChoreographerFrameScheduler() override { stop(); }
    void start(Callback callback, void* userData = nullptr) override;
    void stop() override;
private:
    void scheduleNextFrame(uint64_t lastFrameTimeNanos = 0);
    static void frameCallback(long frameTimeNanos, void* data);
};
#endif

} // namespace thermion
