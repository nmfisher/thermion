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

        EMSCRIPTEN_KEEPALIVE int FrameScheduler_initDartApi(void* data);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithPort(int64_t port, int targetFps);

        // Multi-client deregistration (two engines in one process).
        // FrameScheduler_startWithCallback / FrameScheduler_startWithPort REGISTER a client
        // with one process-shared native scheduler (created on first
        // registration). These remove exactly one client; the scheduler is
        // destroyed when the last client deregisters. FrameScheduler_stop()
        // remains the legacy remove-everything teardown and must not be called
        // while another engine's client is registered.
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_removePort(int64_t port);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_removeCallback(FrameTickCallback callback);

        // Cap the dispatch rate to [fps] by skipping frames at the source.
        // fps <= 0 means unlimited (dispatch every vsync). The value is retained
        // and applied to schedulers created after this call as well.
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_setTargetFps(int fps);

        EMSCRIPTEN_KEEPALIVE int64_t FrameScheduler_steadyClockUs();

#ifdef __cplusplus
    }
}
#endif
