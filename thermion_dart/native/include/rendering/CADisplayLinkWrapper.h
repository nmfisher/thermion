#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*CADisplayLinkFrameCallback)(uint64_t frameTimeNanos, void* context);
void* CADisplayLinkWrapper_create(CADisplayLinkFrameCallback callback, void* context);
void CADisplayLinkWrapper_setTargetFps(void* wrapper, int fps);
void CADisplayLinkWrapper_start(void* wrapper);
void CADisplayLinkWrapper_stop(void* wrapper);
void CADisplayLinkWrapper_destroy(void* wrapper);

#ifdef __cplusplus
}
#endif
