#include "rendering/FrameScheduler.hpp"
#include "Log.hpp"
#include "dart/dart_api_dl.h"
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

void FrameScheduler::dispatchFrame(uint64_t nanos) {
    if (_usePortMode) {
        if (_dartPort != 0) {
            Dart_CObject msg;
            msg.type = Dart_CObject_kInt64;
            msg.value.as_int64 = static_cast<int64_t>(nanos);
            Dart_PostCObject_DL(_dartPort, &msg);
        }
    } else if (_callback) {
        _callback(nanos);
    }
}

void FrameScheduler::resetState() {
    _callback = nullptr;
    _dartPort = 0;
    _usePortMode = false;
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

void TimerFrameScheduler::start(Callback callback) {
    if (_running) return;
    _running = true;
    auto interval = std::chrono::nanoseconds(1000000000 / _targetFps);
    _thread = new std::thread([this, callback, interval]() {
        uint64_t frameCount = 0;
        auto lastActual = std::chrono::high_resolution_clock::now();
        while (_running) {
            auto start = std::chrono::high_resolution_clock::now();
            uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                start.time_since_epoch()).count();

            auto actualIntervalUs = std::chrono::duration_cast<std::chrono::microseconds>(
                start - lastActual).count();
            lastActual = start;

            callback(nanos);

            auto elapsed = std::chrono::high_resolution_clock::now() - start;
            auto callbackUs = std::chrono::duration_cast<std::chrono::microseconds>(elapsed).count();

            if (elapsed < interval) {
                std::this_thread::sleep_for(interval - elapsed);
            }

            frameCount++;
            if (frameCount % 300 == 0) {
                auto targetUs = std::chrono::duration_cast<std::chrono::microseconds>(interval).count();
                std::cerr << "[ThermionVk:Sched] interval=" << actualIntervalUs
                          << "us callback=" << callbackUs
                          << "us target=" << targetUs << "us" << std::endl;
            }
        }
    });
}

void TimerFrameScheduler::startWithPort(int64_t port) {
    if (_running) return;
    _dartPort = port;
    _usePortMode = true;
    _callback = nullptr;
    _running = true;
    auto interval = std::chrono::nanoseconds(1000000000 / _targetFps);
    _thread = new std::thread([this, interval]() {
        while (_running) {
            auto start = std::chrono::high_resolution_clock::now();
            uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                start.time_since_epoch()).count();
            dispatchFrame(nanos);
            auto elapsed = std::chrono::high_resolution_clock::now() - start;
            if (elapsed < interval) {
                std::this_thread::sleep_for(interval - elapsed);
            }
        }
    });
}

void TimerFrameScheduler::stop() {
    _running = false;
    if (_thread) {
        _thread->join();
        delete _thread;
        _thread = nullptr;
    }
}

// ---------------------------------------------------------------------------
// CADisplayLinkScheduler (iOS)
// ---------------------------------------------------------------------------

#if __APPLE__ && TARGET_OS_IOS

void CADisplayLinkScheduler::displayLinkCallback(uint64_t frameTimeNanos, void* context) {
    auto* self = static_cast<CADisplayLinkScheduler*>(context);
    self->dispatchFrame(frameTimeNanos);
}

void CADisplayLinkScheduler::start(Callback callback) {
    stop();
    _callback = callback;
    _usePortMode = false;
    _wrapper = CADisplayLinkWrapper_create(displayLinkCallback, this);
    CADisplayLinkWrapper_start(_wrapper);
}

void CADisplayLinkScheduler::startWithPort(int64_t port) {
    stop();
    _dartPort = port;
    _usePortMode = true;
    _callback = nullptr;
    _wrapper = CADisplayLinkWrapper_create(displayLinkCallback, this);
    CADisplayLinkWrapper_start(_wrapper);
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

void CVDisplayLinkScheduler::start(Callback callback) {
    stop();
    _callback = callback;
    _usePortMode = false;

    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, this);
    CVDisplayLinkStart(_displayLink);
}

void CVDisplayLinkScheduler::startWithPort(int64_t port) {
    stop();
    _dartPort = port;
    _usePortMode = true;
    _callback = nullptr;

    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, this);
    CVDisplayLinkStart(_displayLink);
}

void CVDisplayLinkScheduler::stop() {
    resetState();
    if (_displayLink) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        _displayLink = nullptr;
    }
}

CVReturn CVDisplayLinkScheduler::displayLinkCallback(CVDisplayLinkRef displayLink,
    const CVTimeStamp* inNow, const CVTimeStamp* inOutputTime,
    CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* context) {

    auto* self = static_cast<CVDisplayLinkScheduler*>(context);
    uint64_t nanos = inOutputTime->hostTime;
    self->dispatchFrame(nanos);
    return kCVReturnSuccess;
}

#endif // __APPLE__ && TARGET_OS_OSX

// ---------------------------------------------------------------------------
// DXGIFrameScheduler (Windows)
// ---------------------------------------------------------------------------

#ifdef _WIN32

void DXGIFrameScheduler::start(Callback callback) {
    stop();
    _callback = callback;
    _usePortMode = false;
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
                auto now = std::chrono::high_resolution_clock::now();
                uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                    now.time_since_epoch()).count();
                dispatchFrame(nanos);
            }
        }

        if (output) output->Release();
        if (adapter) adapter->Release();
        if (factory) factory->Release();
    });
}

void DXGIFrameScheduler::startWithPort(int64_t port) {
    stop();
    _dartPort = port;
    _usePortMode = true;
    _callback = nullptr;
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
                auto now = std::chrono::high_resolution_clock::now();
                uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                    now.time_since_epoch()).count();
                dispatchFrame(nanos);
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
    self->dispatchFrame(nanos);

    // Re-schedule for next frame (Choreographer callbacks are one-shot)
    self->scheduleNextFrame();
}

void AChoreographerFrameScheduler::scheduleNextFrame() {
    if (!_running || !_choreographer) return;
    // AChoreographer_postFrameCallback is available from API 24 (deprecated in 29 but still works)
    AChoreographer_postFrameCallback(
        static_cast<AChoreographer*>(_choreographer),
        frameCallback,
        this
    );
}

void AChoreographerFrameScheduler::start(Callback callback) {
    stop();
    _callback = callback;
    _usePortMode = false;
    _running = true;

    _thread = new std::thread([this]() {
        // Prepare looper for this thread
        ALooper* looper = ALooper_prepare(ALOOPER_PREPARE_ALLOW_NON_CALLBACKS);
        _looper = looper;

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
        _looper = nullptr;
    });
}

void AChoreographerFrameScheduler::startWithPort(int64_t port) {
    stop();
    _dartPort = port;
    _usePortMode = true;
    _callback = nullptr;
    _running = true;

    _thread = new std::thread([this]() {
        // Prepare looper for this thread
        ALooper* looper = ALooper_prepare(ALOOPER_PREPARE_ALLOW_NON_CALLBACKS);
        _looper = looper;

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
        _looper = nullptr;
    });
}

void AChoreographerFrameScheduler::stop() {
    _running = false;

    // Wake up the looper so it can exit
    if (_looper) {
        ALooper_wake(static_cast<ALooper*>(_looper));
    }

    if (_thread) {
        _thread->join();
        delete _thread;
        _thread = nullptr;
    }
    resetState();
    _choreographer = nullptr;
    _looper = nullptr;
}

#endif // __ANDROID__

} // namespace thermion
