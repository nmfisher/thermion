#pragma once

#include "APIBoundaryTypes.h"

// Preserve the historical generated-binding declaration order without making
// the production timing API depend on rendering types.
#ifdef THERMION_FFIGEN
#include "TRenderManager.h"
#endif

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif
        typedef void (*FrameTickCallback)(uint64_t frameTimeNanos);

        EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithCallback(FrameTickCallback tickCallback, int targetFps);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_stop();

        EMSCRIPTEN_KEEPALIVE int FrameScheduler_initDartApi(void* data);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithPort(int64_t port, int targetFps);

        EMSCRIPTEN_KEEPALIVE void FrameScheduler_setTargetFps(int fps);

        EMSCRIPTEN_KEEPALIVE int64_t FrameScheduler_steadyClockUs();

#ifdef __cplusplus
    }
}
#endif
