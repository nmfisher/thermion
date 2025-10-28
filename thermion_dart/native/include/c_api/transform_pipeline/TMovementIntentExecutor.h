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

EMSCRIPTEN_KEEPALIVE TMovementIntentExecutor* create_default_transform_executor(void* engine);
EMSCRIPTEN_KEEPALIVE void movement_intent_executor_destroy(TMovementIntentExecutor* processor);
EMSCRIPTEN_KEEPALIVE void pipeline_register_movement_intent_executor(TMovementIntentExecutor* processor);
EMSCRIPTEN_KEEPALIVE void movement_intent_executor_set_target_entity(TMovementIntentExecutor* processor, uint32_t entityId);

#ifdef __cplusplus
}
}
#endif