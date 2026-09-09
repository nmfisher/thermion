#include "rendering/FrameScheduler.hpp"
#include "Log.hpp"
#include <algorithm>
#include <iostream>

#if __APPLE__ && TARGET_OS_IOS
#include "rendering/CADisplayLinkWrapper.h"
#endif

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <dxgi.h>
#pragma comment(lib, "dxgi.lib")
#endif

#ifdef __ANDROID__
#include <android/choreographer.h>
#include <android/looper.h>
#endif

namespace thermion {

static uint64_t steadyClockNanos() {
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

// ---------------------------------------------------------------------------
// FrameScheduler (base helpers)
// ---------------------------------------------------------------------------

void FrameScheduler::setTargetFps(int fps) {
    const int normalizedFps = fps > 0 ? fps : 0;
    const int previousFps = _fpsLimit.exchange(
        normalizedFps, std::memory_order_relaxed);
    if (previousFps != normalizedFps) {
        onTargetFpsChanged(normalizedFps);
    }
}

void FrameScheduler::handleSourceTick(uint64_t nanos) {
    if (!_rateGate.admit(nanos, _fpsLimit.load(std::memory_order_relaxed))) {
        return;
    }

    if (_tickCallback) {
        _tickCallback(nanos, _tickUserData);
    }
}

void FrameScheduler::resetState() {
    _tickCallback = nullptr;
    _tickUserData = nullptr;
    _rateGate.reset();
}

FrameScheduler* FrameScheduler::create(int targetFps) {
    int fps = targetFps > 0 ? targetFps : 60;
#if __APPLE__ && TARGET_OS_OSX
    return new CVDisplayLinkScheduler();
#elif __APPLE__ && TARGET_OS_IOS
    return new CADisplayLinkScheduler();
#elif defined(_WIN32)
    return new DXGIFrameScheduler(fps);
#elif defined(__ANDROID__)
    return new AChoreographerFrameScheduler();
#else
    return new TimerFrameScheduler(fps);
#endif
}

// ---------------------------------------------------------------------------
// TimerFrameScheduler
// ---------------------------------------------------------------------------

void TimerFrameScheduler::onTargetFpsChanged(int) {
    // Synchronize with condition_variable::wait_until so a rate change cannot
    // land between its predicate check and the thread actually blocking.
    std::lock_guard<std::mutex> lock(_wakeMutex);
    _wakeCondition.notify_all();
}

void FrameScheduler::runTimerLoop(std::atomic<bool>& running, int fallbackFps,
        std::mutex& wakeMutex, std::condition_variable& wakeCondition) {
    using Clock = std::chrono::steady_clock;

    int appliedSourceFps = 0;
    std::chrono::nanoseconds sourceInterval{0};
    auto nextWake = Clock::now();
    auto lastActual = nextWake;
    uint64_t frameCount = 0;

    while (running.load(std::memory_order_relaxed)) {
        const int requestedFps = _fpsLimit.load(std::memory_order_relaxed);
        const int sourceFps = requestedFps > 0
            ? requestedFps
            : std::max(1, fallbackFps);
        if (sourceFps != appliedSourceFps) {
            appliedSourceFps = sourceFps;
            sourceInterval = std::chrono::nanoseconds(
                std::max<uint64_t>(
                    1, 1000000000ULL / static_cast<uint64_t>(sourceFps)));
            // Apply both increases and decreases immediately. handleSourceTick()
            // resets its deadline on the same target-FPS change.
            nextWake = Clock::now();
        }

        const auto start = Clock::now();
        const uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
            start.time_since_epoch()).count();
        const auto actualIntervalUs = std::chrono::duration_cast<std::chrono::microseconds>(
            start - lastActual).count();
        lastActual = start;

        handleSourceTick(nanos);

        const auto callbackElapsed = Clock::now() - start;
        const auto callbackUs = std::chrono::duration_cast<std::chrono::microseconds>(
            callbackElapsed).count();

        ++frameCount;
        if (frameCount % 300 == 0) {
            const auto targetUs = std::chrono::duration_cast<std::chrono::microseconds>(
                sourceInterval).count();
            std::cerr << "[ThermionVk:Sched] interval=" << actualIntervalUs
                      << "us callback=" << callbackUs
                      << "us target=" << targetUs << "us" << std::endl;
        }

        nextWake += sourceInterval;
        const auto now = Clock::now();
        if (nextWake <= now) {
            const auto missedIntervals =
                (now - nextWake) / sourceInterval + 1;
            nextWake += sourceInterval * missedIntervals;
        }

        std::unique_lock<std::mutex> lock(wakeMutex);
        wakeCondition.wait_until(lock, nextWake, [this, appliedSourceFps, fallbackFps, &running]() {
            const int requestedFps = _fpsLimit.load(std::memory_order_relaxed);
            const int sourceFps = requestedFps > 0
                ? requestedFps
                : std::max(1, fallbackFps);
            return !running.load(std::memory_order_relaxed) ||
                sourceFps != appliedSourceFps;
        });
    }
}

void TimerFrameScheduler::start(TickCallback tickCallback, void* userData) {
    if (_running) return;
    _tickCallback = tickCallback;
    _tickUserData = userData;
    _running = true;
    _thread = new std::thread([this]() {
        runTimerLoop(_running, _targetFps, _wakeMutex, _wakeCondition);
    });
}

void TimerFrameScheduler::stop() {
    {
        std::lock_guard<std::mutex> lock(_wakeMutex);
        _running = false;
    }
    _wakeCondition.notify_all();
    if (_thread) {
        _thread->join();
        delete _thread;
        _thread = nullptr;
    }
    resetState();
}

// ---------------------------------------------------------------------------
// CADisplayLinkScheduler (iOS)
// ---------------------------------------------------------------------------

#if __APPLE__ && TARGET_OS_IOS

void CADisplayLinkScheduler::displayLinkCallback(uint64_t frameTimeNanos, void* context) {
    auto* self = static_cast<CADisplayLinkScheduler*>(context);
    const uint64_t sourceNow = CADisplayLinkWrapper_currentTimeNanos();
    const uint64_t steadyNow = steadyClockNanos();
    self->handleSourceTick(self->_frameTime.map(frameTimeNanos, sourceNow, steadyNow));
}

void CADisplayLinkScheduler::start(TickCallback tickCallback, void* userData) {
    stop();
    _tickCallback = tickCallback;
    _tickUserData = userData;
    _wrapper = CADisplayLinkWrapper_create(displayLinkCallback, this);
    CADisplayLinkWrapper_setTargetFps(
        _wrapper, _fpsLimit.load(std::memory_order_relaxed));
    CADisplayLinkWrapper_start(_wrapper);
}

void CADisplayLinkScheduler::onTargetFpsChanged(int fps) {
    if (_wrapper) {
        CADisplayLinkWrapper_setTargetFps(_wrapper, fps);
    }
}

void CADisplayLinkScheduler::stop() {
    if (_wrapper) {
        CADisplayLinkWrapper_destroy(_wrapper);
        _wrapper = nullptr;
    }
    resetState();
    _frameTime.reset();
}

#endif // __APPLE__ && TARGET_OS_IOS

// ---------------------------------------------------------------------------
// CVDisplayLinkScheduler (macOS)
// ---------------------------------------------------------------------------

#if __APPLE__ && TARGET_OS_OSX

void CVDisplayLinkScheduler::start(TickCallback tickCallback, void* userData) {
    stop();
    _tickCallback = tickCallback;
    _tickUserData = userData;
    mach_timebase_info(&_timebase);

    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, this);
    CVDisplayLinkStart(_displayLink);
}

void CVDisplayLinkScheduler::stop() {
    if (_displayLink) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        _displayLink = nullptr;
    }
    resetState();
    _frameTime.reset();
}

CVReturn CVDisplayLinkScheduler::displayLinkCallback(CVDisplayLinkRef displayLink,
    const CVTimeStamp* inNow, const CVTimeStamp* inOutputTime,
    CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* context) {

    auto* self = static_cast<CVDisplayLinkScheduler*>(context);
    const uint64_t sourceNow = machTimeNanos(mach_absolute_time(), self->_timebase);
    const uint64_t steadyNow = steadyClockNanos();
    self->handleSourceTick(self->_frameTime.map(
        precedingVsyncNanos(*inOutputTime, self->_timebase), sourceNow, steadyNow));
    return kCVReturnSuccess;
}

#endif // __APPLE__ && TARGET_OS_OSX

// ---------------------------------------------------------------------------
// DXGIFrameScheduler (Windows)
// ---------------------------------------------------------------------------

#ifdef _WIN32

bool DXGIFrameScheduler::waitForVBlank(IDXGIOutput* output) {
    return output && SUCCEEDED(output->WaitForVBlank());
}

void DXGIFrameScheduler::start(TickCallback tickCallback, void* userData) {
    stop();
    _tickCallback = tickCallback;
    _tickUserData = userData;
    _running = true;

    _thread = new std::thread([this]() {
        IDXGIFactory1* factory = nullptr;
        IDXGIAdapter* adapter = nullptr;
        IDXGIOutput* output = nullptr;

        HRESULT hr = CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&factory);
        if (SUCCEEDED(hr) && factory) {
            hr = factory->EnumAdapters(0, &adapter);
            if (SUCCEEDED(hr) && adapter) {
                hr = adapter->EnumOutputs(0, &output);
                if (FAILED(hr)) {
                    output = nullptr;
                    Log("DXGIFrameScheduler: Failed to get DXGI output for WaitForVBlank, falling back to timer");
                }
            }
        }

        while (_running) {
            if (!waitForVBlank(output)) {
                Log("DXGIFrameScheduler: VBlank unavailable, falling back to timer");
                if (output) output->Release();
                output = nullptr;
                runTimerLoop(_running, _targetFps, _wakeMutex, _wakeCondition);
                break;
            }
            if (_running) {
                handleSourceTick(steadyClockNanos());
            }
        }

        if (output) output->Release();
        if (adapter) adapter->Release();
        if (factory) factory->Release();
    });
}

void DXGIFrameScheduler::onTargetFpsChanged(int) {
    std::lock_guard<std::mutex> lock(_wakeMutex);
    _wakeCondition.notify_all();
}

void DXGIFrameScheduler::stop() {
    {
        std::lock_guard<std::mutex> lock(_wakeMutex);
        _running = false;
    }
    _wakeCondition.notify_all();
    if (_thread) {
        _thread->join();
        delete _thread;
        _thread = nullptr;
    }
    resetState();
}

#endif // _WIN32

// ---------------------------------------------------------------------------
// AChoreographerFrameScheduler (Android)
// ---------------------------------------------------------------------------

#ifdef __ANDROID__

void AChoreographerFrameScheduler::frameCallback(long frameTimeNanos, void* data) {
    auto* self = static_cast<AChoreographerFrameScheduler*>(data);
    if (!self->_running) return;

    uint64_t nanos = static_cast<uint64_t>(frameTimeNanos);
    self->handleSourceTick(nanos);

    // Re-schedule for next frame (Choreographer callbacks are one-shot)
    self->scheduleNextFrame();
}

void AChoreographerFrameScheduler::scheduleNextFrame() {
    if (!_running || !_choreographer) return;
    // Register immediately. Delaying registration until the target deadline
    // can miss that vsync when the looper wakes late. handleSourceTick() owns
    // all rate admission, including non-divisor and changing refresh rates.
    AChoreographer_postFrameCallback(
        static_cast<AChoreographer*>(_choreographer), frameCallback, this);
}

void AChoreographerFrameScheduler::start(TickCallback tickCallback, void* userData) {
    stop();
    _tickCallback = tickCallback;
    _tickUserData = userData;
    _running = true;

    _thread = new std::thread([this]() {
        // Prepare looper for this thread
        ALooper* looper = ALooper_prepare(ALOOPER_PREPARE_ALLOW_NON_CALLBACKS);
        _looper.store(looper, std::memory_order_release);

        // Get choreographer instance for this thread
        AChoreographer* choreographer = AChoreographer_getInstance();
        if (!choreographer) {
            Log("AChoreographerFrameScheduler: Failed to get AChoreographer instance");
            _running = false;
            return;
        }
        _choreographer = choreographer;

        // Post first frame callback
        scheduleNextFrame();

        // Run the looper - this blocks and processes choreographer callbacks
        while (_running) {
            int result = ALooper_pollOnce(-1, nullptr, nullptr, nullptr);
            if (result == ALOOPER_POLL_ERROR) {
                Log("AChoreographerFrameScheduler: Looper error");
                break;
            }
        }

        _choreographer = nullptr;
        _looper.store(nullptr, std::memory_order_release);
    });
}

void AChoreographerFrameScheduler::stop() {
    _running = false;

    // Wake up the looper so it can exit
    if (void* looper = _looper.load(std::memory_order_acquire)) {
        ALooper_wake(static_cast<ALooper*>(looper));
    }

    if (_thread) {
        _thread->join();
        delete _thread;
        _thread = nullptr;
    }
    resetState();
    _choreographer = nullptr;
    _looper.store(nullptr, std::memory_order_release);
}

#endif // __ANDROID__

} // namespace thermion
