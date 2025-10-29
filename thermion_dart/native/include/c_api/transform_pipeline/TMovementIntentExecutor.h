#pragma once

#ifndef EMSCRIPTEN_KEEPALIVE
#define EMSCRIPTEN_KEEPALIVE
#endif

#include <stdint.h>

#ifdef __cplusplus
namespace thermion::plugin::input {
extern "C" {
#endif

typedef struct TMovementIntentExecutor TMovementIntentExecutor;

EMSCRIPTEN_KEEPALIVE TMovementIntentExecutor* MovementIntentExecutor_createDefault(void* engine);
EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_destroy(TMovementIntentExecutor* processor);
EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_setTargetEntity(TMovementIntentExecutor* processor, uint32_t entityId);
EMSCRIPTEN_KEEPALIVE void Pipeline_registerMovementIntentExecutor(TMovementIntentExecutor* processor);

#ifdef __cplusplus
}
}
#endif