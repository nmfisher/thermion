#pragma once

#include <stdint.h>

#include "c_api/APIExport.h"
#include "c_api/APIBoundaryTypes.h"
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

EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_destroy(TMovementIntentExecutor* executor);
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