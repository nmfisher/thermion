#include "rendering/FrameScheduler.hpp"
#include "Log.hpp"
#include <algorithm>
#include <iostream>

#if __APPLE__ && TARGET_OS_IOS
#include "rendering/CADisplayLinkWrapper.h"
#endif

#ifdef _WIN32
#include <dxgi.h>
#pragma comment(lib, "dxgi.lib")
#endif

#ifdef __ANDROID__
#include <android/choreographer.h>
#include <android/looper.h>
#endif

namespace thermion {

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
    // Framerate limiting: use an absolute deadline rather than measuring from
    // the last dispatched vsync. This preserves the requested average on
    // refresh rates that are not integer multiples of the target (for example,
    // 60 fps on a 90 Hz display alternates one- and two-vsync intervals instead
    // of collapsing to 45 fps).
    int fps = _fpsLimit.load(std::memory_order_relaxed);
    if (fps > 0) {
        const uint64_t tolerance = 1000000ULL; // 1 ms

        if (_appliedFpsLimit != fps || _nextDispatchNs == 0) {
            _appliedFpsLimit = fps;
            _dispatchIntervalNs = std::max<uint64_t>(
                1, 1000000000ULL / static_cast<uint64_t>(fps));
            _nextDispatchNs = nanos;
        }

        if (_nextDispatchNs > nanos &&
            _nextDispatchNs - nanos > tolerance) {
            return; // next target deadline has not arrived — skip
        }

        // Advance by whole target intervals, dropping any deadlines missed
        // while the scheduler/render thread was stalled. Never burst frames to
        // catch up.
        if (_nextDispatchNs <= nanos) {
            const uint64_t missedIntervals =
                (nanos - _nextDispatchNs) / _dispatchIntervalNs + 1;
            _nextDispatchNs += missedIntervals * _dispatchIntervalNs;
        } else {
            // Accepted up to [tolerance] before the deadline.
            _nextDispatchNs += _dispatchIntervalNs;
        }
    } else {
        _appliedFpsLimit = 0;
        _dispatchIntervalNs = 0;
        _nextDispatchNs = 0;
    }

    if (_callback) {
        _callback(nanos, _callbackUserData);
    }
}

void FrameScheduler::resetState() {
    _callback = nullptr;
    _callbackUserData = nullptr;
    _appliedFpsLimit = 0;
    _dispatchIntervalNs = 0;
    _nextDispatchNs = 0;
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

void TimerFrameScheduler::run() {
    using Clock = std::chrono::steady_clock;

    int appliedSourceFps = 0;
    std::chrono::nanoseconds sourceInterval{0};
    auto nextWake = Clock::now();
    auto lastActual = nextWake;
    uint64_t frameCount = 0;

    while (_running.load(std::memory_order_relaxed)) {
        const int requestedFps = _fpsLimit.load(std::memory_order_relaxed);
        const int sourceFps = requestedFps > 0
            ? requestedFps
            : std::max(1, _targetFps);
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

        std::unique_lock<std::mutex> lock(_wakeMutex);
        _wakeCondition.wait_until(lock, nextWake, [this, appliedSourceFps]() {
            const int requestedFps = _fpsLimit.load(std::memory_order_relaxed);
            const int sourceFps = requestedFps > 0
                ? requestedFps
                : std::max(1, _targetFps);
            return !_running.load(std::memory_order_relaxed) ||
                sourceFps != appliedSourceFps;
        });
    }
}

void TimerFrameScheduler::start(Callback callback, void* userData) {
    if (_running) return;
    _callback = callback;
    _callbackUserData = userData;
    _running = true;
    _thread = new std::thread([this]() { run(); });
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
    self->handleSourceTick(frameTimeNanos);
}

void CADisplayLinkScheduler::start(Callback callback, void* userData) {
    stop();
    _callback = callback;
    _callbackUserData = userData;
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
}

#endif // __APPLE__ && TARGET_OS_IOS

// ---------------------------------------------------------------------------
// CVDisplayLinkScheduler (macOS)
// ---------------------------------------------------------------------------

#if __APPLE__ && TARGET_OS_OSX

void CVDisplayLinkScheduler::start(Callback callback, void* userData) {
    stop();
    _callback = callback;
    _callbackUserData = userData;
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
}

CVReturn CVDisplayLinkScheduler::displayLinkCallback(CVDisplayLinkRef displayLink,
    const CVTimeStamp* inNow, const CVTimeStamp* inOutputTime,
    CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* context) {

    auto* self = static_cast<CVDisplayLinkScheduler*>(context);
    // hostTime is Mach absolute time; convert to nanoseconds so the rate gate's
    // interval math is unit-correct on every Mac (Apple Silicon is 1:1, but
    // don't assume it).
    uint64_t hostTime = inOutputTime->hostTime;
    uint64_t nanos = hostTime * self->_timebase.numer / self->_timebase.denom;
    self->handleSourceTick(nanos);
    return kCVReturnSuccess;
}

#endif // __APPLE__ && TARGET_OS_OSX

// ---------------------------------------------------------------------------
// DXGIFrameScheduler (Windows)
// ---------------------------------------------------------------------------

#ifdef _WIN32

void DXGIFrameScheduler::start(Callback callback, void* userData) {
    stop();
    _callback = callback;
    _callbackUserData = userData;
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

        auto interval = std::chrono::nanoseconds(1000000000 / _targetFps);
        while (_running) {
            if (output) {
                output->WaitForVBlank();
            } else {
                std::this_thread::sleep_for(interval);
            }
            if (_running) {
                auto now = std::chrono::steady_clock::now();
                uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                    now.time_since_epoch()).count();
                handleSourceTick(nanos);
            }
        }

        if (output) output->Release();
        if (adapter) adapter->Release();
        if (factory) factory->Release();
    });
}

void DXGIFrameScheduler::stop() {
    _running = false;
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
    self->scheduleNextFrame(nanos);
}

void AChoreographerFrameScheduler::scheduleNextFrame(uint64_t lastFrameTimeNanos) {
    if (!_running || !_choreographer) return;

    long delayMillis = 0;
    const int fps = _fpsLimit.load(std::memory_order_relaxed);
    if (fps > 0 && lastFrameTimeNanos != 0) {
        const uint64_t interval = std::max<uint64_t>(
            1, 1000000000ULL / static_cast<uint64_t>(fps));
        if (_sourceFps != fps || _nextSourceFrameNs == 0) {
            _sourceFps = fps;
            _nextSourceFrameNs = lastFrameTimeNanos + interval;
        } else if (_nextSourceFrameNs <= lastFrameTimeNanos) {
            const uint64_t missedIntervals =
                (lastFrameTimeNanos - _nextSourceFrameNs) / interval + 1;
            _nextSourceFrameNs += missedIntervals * interval;
        }

        const auto now = std::chrono::steady_clock::now();
        const uint64_t nowNanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
            now.time_since_epoch()).count();
        if (_nextSourceFrameNs > nowNanos) {
            // Round down so the callback is eligible for the first vsync at
            // the target deadline rather than accidentally slipping one.
            delayMillis = static_cast<long>(
                (_nextSourceFrameNs - nowNanos) / 1000000ULL);
        }
    } else {
        _sourceFps = 0;
        _nextSourceFrameNs = 0;
    }

    if (delayMillis > 0) {
        AChoreographer_postFrameCallbackDelayed(
            static_cast<AChoreographer*>(_choreographer),
            frameCallback,
            this,
            delayMillis);
    } else {
        AChoreographer_postFrameCallback(
            static_cast<AChoreographer*>(_choreographer),
            frameCallback,
            this);
    }
}

void AChoreographerFrameScheduler::start(Callback callback, void* userData) {
    stop();
    _callback = callback;
    _callbackUserData = userData;
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
    _sourceFps = 0;
    _nextSourceFrameNs = 0;
    _choreographer = nullptr;
    _looper.store(nullptr, std::memory_order_release);
}

#endif // __ANDROID__

} // namespace thermion
