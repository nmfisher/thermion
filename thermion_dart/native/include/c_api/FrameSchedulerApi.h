#pragma once

#include "APIBoundaryTypes.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif
        // Nanoseconds in the native steady-clock time base, not wall-clock time.
        // Display sources estimate vsync time; missing Apple timing metadata and
        // timer sources use delivery time. Forward this value to render work to
        // retain source timing. See rendering/FrameScheduler.hpp for the contract.
        typedef void (*FrameTickCallback)(uint64_t frameTimeNanos);

        EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithCallback(FrameTickCallback tickCallback, int targetFps);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_stop();

        // Stops the scheduler as FrameScheduler_stop does, in the signature of
        // a Dart NativeFinalizer callback, which ignores its token. The Dart
        // VM runs attached native finalizers when the isolate group shuts
        // down, so the scheduler never ticks a Dart callback the VM has torn
        // down. A tick after VM shutdown aborts the process.
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_finalize(void* token);

        EMSCRIPTEN_KEEPALIVE int FrameScheduler_initDartApi(void* data);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithPort(int64_t port, int targetFps);

        EMSCRIPTEN_KEEPALIVE void FrameScheduler_setTargetFps(int fps);

        EMSCRIPTEN_KEEPALIVE int64_t FrameScheduler_steadyClockUs();

#ifdef __cplusplus
    }
}
#endif
