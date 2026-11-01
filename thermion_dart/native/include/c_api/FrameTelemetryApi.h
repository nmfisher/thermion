#pragma once

#include <stdint.h>
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
namespace thermion
{
    // Called by RenderManager::render() after a frame was actually rendered.
    // One relaxed atomic load when telemetry is disabled.
    void FrameTelemetry_record();

    extern "C"
    {
#endif
        // Telemetry is disabled by default.
        EMSCRIPTEN_KEEPALIVE void FrameTelemetry_enable();
        EMSCRIPTEN_KEEPALIVE void FrameTelemetry_disable();
        // Copies up to `cap` not-yet-drained steady_clock timestamps (ns, oldest
        // first) into `out`; returns the count written. If more than 256 frames
        // accumulated since the last drain, only the newest 256 are returned.
        EMSCRIPTEN_KEEPALIVE int FrameTelemetry_drain(uint64_t *out, int cap);
#ifdef __cplusplus
    }
}
#endif
