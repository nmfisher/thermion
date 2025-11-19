#pragma once

#include "c_api/APIExport.h"
#include "c_api/APIBoundaryTypes.h"

#include "ffigen_fix.h"

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

// Input configuration functions
EMSCRIPTEN_KEEPALIVE void TransformPipeline_addKeyBinding(int logicalKey, int intentAction, float value);
EMSCRIPTEN_KEEPALIVE void TransformPipeline_removeKeyBindingsForKey(int logicalKey);
EMSCRIPTEN_KEEPALIVE void TransformPipeline_removeKeyBindingsForAction(int intentAction);
EMSCRIPTEN_KEEPALIVE void TransformPipeline_clearKeyBindings();
EMSCRIPTEN_KEEPALIVE void TransformPipeline_setMouseSensitivity(float sensitivity);
EMSCRIPTEN_KEEPALIVE void TransformPipeline_setInvertMouseY(bool invert);

#ifdef __cplusplus
}
#endif