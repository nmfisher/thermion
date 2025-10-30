#include "c_api/transform_pipeline/TInputHandlerPipeline.h"
#include "transform_pipeline/InputEventManager.hpp"
#include "transform_pipeline/MovementIntentCalculator.hpp"
#include "transform_pipeline/Pipeline.hpp"
#include "transform_pipeline/PipelineStage.hpp"

#include "Log.hpp"

#include <utils/Entity.h>

/**
 * Public C API functions for Dart FFI integration.
 * Bridges the C interface to the C++ InputEventManager and MovementIntentCalculator.
 */

#ifdef __cplusplus
extern "C" {
namespace thermion::plugin::input {
#endif

using namespace thermion;

EMSCRIPTEN_KEEPALIVE void TransformPipeline_setEngine(void* enginePtr) {
    auto pipeline = getPipeline();
    if (pipeline && enginePtr) {
        filament::Engine* engine = static_cast<filament::Engine*>(enginePtr);
        pipeline->setEngine(engine);
    }
}



EMSCRIPTEN_KEEPALIVE void TransformPipeline_onMouseEvent(
    int eventType, int button,
    double localX, double localY, double deltaX, double deltaY) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto eventManager = pipeline->getEventManager();
        if (eventManager) {
            // Convert C parameters to C++ MouseEvent
            MouseEvent event;
            event.type = static_cast<MouseEventType>(eventType);
            event.button = button >= 0 ? std::optional<MouseButton>(static_cast<MouseButton>(button)) : std::nullopt;
            event.localPosition = {static_cast<float>(localX), static_cast<float>(localY)};
            event.delta = {static_cast<float>(deltaX), static_cast<float>(deltaY)};

            eventManager->handleMouseEvent(event);
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_onKeyEvent(
    int eventType, int logicalKey, int physicalKey, int synthesized) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto eventManager = pipeline->getEventManager();
        if (eventManager) {
            // Convert C parameters to C++ KeyEvent
            KeyEvent event;
            event.type = static_cast<KeyEventType>(eventType);
            event.logicalKey = static_cast<LogicalKey>(logicalKey);
            event.physicalKey = static_cast<PhysicalKey>(physicalKey);
            event.synthesized = synthesized != 0;

            eventManager->handleKeyEvent(event);
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_onScrollEvent(
    double localX, double localY, double delta) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto eventManager = pipeline->getEventManager();
        if (eventManager) {
            // Convert C parameters to C++ ScrollEvent
            ScrollEvent event;
            event.localPosition = {static_cast<float>(localX), static_cast<float>(localY)};
            event.delta = delta;

            eventManager->handleScrollEvent(event);
        }
    }
}


EMSCRIPTEN_KEEPALIVE void TransformPipeline_update(float deltaTime) {
    TRACE("[C API] DELTA_TIME_DEBUG: update_pipeline called with deltaTime=%.6f", deltaTime);
    auto pipeline = getPipeline();
    if (pipeline) {
        TRACE("[C API] DELTA_TIME_DEBUG: Pipeline found, calling update with deltaTime=%.6f", deltaTime);
        pipeline->update(deltaTime);
    } else {
        TRACE("[C API] DELTA_TIME_DEBUG: ERROR - getPipeline() returned null!");
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_registerPipelineStage(void* pipelineStageHandle, const char* name) {
    auto pipeline = getPipeline();
    if (pipeline && pipelineStageHandle) {
        // Cast the opaque handle to PipelineStage* - this works because
        // TPhysicsComponentManager* is reinterpret_cast from the actual C++ object
        auto* stage = reinterpret_cast<PipelineStage*>(pipelineStageHandle);
        pipeline->registerPipelineStage(stage);
        TRACE("[C API] Registered pipeline stage: %s", name ? name : "Unknown");
    } else {
        TRACE("[C API] ERROR - Failed to register pipeline stage: %s (pipeline=%p, handle=%p)",
              name ? name : "Unknown", pipeline, pipelineStageHandle);
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_unregisterPipelineStage(void* pipelineStageHandle) {
    auto pipeline = getPipeline();
    if (pipeline && pipelineStageHandle) {
        // Cast the opaque handle to PipelineStage*
        auto* stage = reinterpret_cast<PipelineStage*>(pipelineStageHandle);
        pipeline->unregisterPipelineStage(stage);
        TRACE("[C API] Unregistered pipeline stage");
    } else {
        TRACE("[C API] ERROR - Failed to unregister pipeline stage (pipeline=%p, handle=%p)",
              pipeline, pipelineStageHandle);
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_cleanup() {
    TRACE("[C API] Cleaning up pipeline");
    auto pipeline = getPipeline();
    if (pipeline) {
        pipeline->cleanup();
        TRACE("[C API] Pipeline cleanup completed");
    } else {
        TRACE("[C API] ERROR - Failed to cleanup pipeline - pipeline is null");
    }
}

#ifdef __cplusplus
}
}
#endif