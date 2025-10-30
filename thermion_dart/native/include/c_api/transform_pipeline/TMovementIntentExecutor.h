#pragma once

#ifndef EMSCRIPTEN_KEEPALIVE
#define EMSCRIPTEN_KEEPALIVE
#endif

#include <stdint.h>
#include "TMovementIntentCalculator.h"

#ifdef __cplusplus
namespace thermion::plugin::input {
extern "C" {
#endif

typedef struct TMovementIntentExecutor TMovementIntentExecutor;

// Movement space enum (must match C++ MovementSpace)
typedef enum {
    MOVEMENT_SPACE_WORLD = 0,
    MOVEMENT_SPACE_OBJECT = 1
} TMovementSpace;

// Movement configuration structure
typedef struct {
    double baseMoveSpeed;
    double mouseSensitivity;
    int invertHorizontalMovement;  // 0 = false, non-zero = true
    TMovementSpace movementSpace;
    double jumpHeight;
    double groundLevel;
} TMovementConfig;

EMSCRIPTEN_KEEPALIVE TMovementIntentExecutor* MovementIntentExecutor_createDefault(void* engine);
EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_destroy(TMovementIntentExecutor* executor);
EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_setTargetEntity(TMovementIntentExecutor* executor, uint32_t entityId);
EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_setConfig(TMovementIntentExecutor* executor, TMovementConfig *tConfig);
EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_process(
    TMovementIntentExecutor* executor,
    const TMovementIntent* intent,
    uint64_t deltaTimeInNanos
);
EMSCRIPTEN_KEEPALIVE void Pipeline_registerMovementIntentExecutor(TMovementIntentExecutor* executor);

#ifdef __cplusplus
}
}
#endif