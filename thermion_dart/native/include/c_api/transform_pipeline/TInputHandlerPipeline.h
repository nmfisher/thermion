#pragma once

#include "c_api/APIExport.h"
#include "c_api/APIBoundaryTypes.h"

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TInputHandler TInputHandler;

// Component manager functions
EMSCRIPTEN_KEEPALIVE void TransformPipeline_setEngine(void* enginePtr);

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

// Manual pipeline update (fallback for when automatic updates don't work)
EMSCRIPTEN_KEEPALIVE void TransformPipeline_update(float deltaTime);

// Pipeline stage registration functions
EMSCRIPTEN_KEEPALIVE void TransformPipeline_registerPipelineStage(void* pipelineStageHandle, const char* name);
EMSCRIPTEN_KEEPALIVE void TransformPipeline_unregisterPipelineStage(void* pipelineStageHandle);

// Pipeline cleanup function
EMSCRIPTEN_KEEPALIVE void TransformPipeline_cleanup();

#ifdef __cplusplus
}
#endif