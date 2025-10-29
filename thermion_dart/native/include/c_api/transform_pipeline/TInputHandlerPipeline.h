#pragma once

#ifndef EMSCRIPTEN_KEEPALIVE
#define EMSCRIPTEN_KEEPALIVE
#endif

#include <stdint.h>

#ifdef __cplusplus
namespace thermion::plugin::input {
extern "C" {
#endif

typedef struct TInputHandler TInputHandler;

// Component manager functions
EMSCRIPTEN_KEEPALIVE void TransformPipeline_set_engine(void* enginePtr);

// Input event functions (global - no entity ID required)
EMSCRIPTEN_KEEPALIVE void TransformPipeline_onMouseEvent(
    int eventType, int button,
    double localX, double localY, double deltaX, double deltaY
);

EMSCRIPTEN_KEEPALIVE void TransformPipeline_onKeyEvent(
    int eventType, int logicalKey, int physicalKey, int synthesized
);

EMSCRIPTEN_KEEPALIVE void TransformPipeline_onScrollEvent(
    double localX, double localY, double delta
);

EMSCRIPTEN_KEEPALIVE void TransformPipeline_set_movement_space(
    uint32_t entityId, int movementSpace
);

EMSCRIPTEN_KEEPALIVE void TransformPipeline_set_invert_horizontal_movement(
    uint32_t entityId, int invert
);

EMSCRIPTEN_KEEPALIVE void TransformPipeline_set_movement_speed(
    uint32_t entityId, double speed
);

EMSCRIPTEN_KEEPALIVE void TransformPipeline_setMouseSensitivity(
    uint32_t entityId, double sensitivity
);


// Manual pipeline update (fallback for when automatic updates don't work)
EMSCRIPTEN_KEEPALIVE void TransformPipeline_update_pipeline(float deltaTime);

// Pipeline stage registration functions
EMSCRIPTEN_KEEPALIVE void TransformPipeline_registerPipelineStage(void* pipelineStageHandle, const char* name);
EMSCRIPTEN_KEEPALIVE void TransformPipeline_unregisterPipelineStage(void* pipelineStageHandle);

// Pipeline cleanup function
EMSCRIPTEN_KEEPALIVE void TransformPipeline_cleanup();

#ifdef __cplusplus
}
}
#endif