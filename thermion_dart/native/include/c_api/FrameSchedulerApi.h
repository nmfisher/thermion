#pragma once

#include "APIBoundaryTypes.h"
#include "TRenderManager.h"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
#endif
        typedef void (*FrameCallback)(uint64_t frameTimeNanos);
        typedef void (*PostRenderCallback)(void* userData);

        EMSCRIPTEN_KEEPALIVE void FrameScheduler_start(FrameCallback callback, int targetFps);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_stop();

        EMSCRIPTEN_KEEPALIVE void FrameScheduler_setRenderThread(void* renderThread);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_setRenderManager(TRenderManager* rm);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_setPostRenderCallback(PostRenderCallback callback, void* userData);
        EMSCRIPTEN_KEEPALIVE bool FrameScheduler_requestRender(uint64_t frameTimeNanos);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_startNativeRenderLoop(int targetFps);

        EMSCRIPTEN_KEEPALIVE int FrameScheduler_initDartApi(void* data);
        EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithPort(int64_t port, int targetFps);

        EMSCRIPTEN_KEEPALIVE void FrameScheduler_setTargetFps(int fps);

        EMSCRIPTEN_KEEPALIVE int64_t FrameScheduler_steadyClockUs();

#ifdef __cplusplus
    }
}
#endif
