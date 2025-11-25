#include "c_api/transform_pipeline/TTransformPipeline.h"
#include "transform_pipeline/InputEventManager.hpp"
#include "transform_pipeline/MovementIntentCalculator.hpp"
#include "transform_pipeline/Pipeline.hpp"
#include "transform_pipeline/PipelineStage.hpp"

#include "Log.hpp"

#include <utils/Entity.h>

extern "C" {

using namespace thermion;
using namespace thermion::plugin::input;


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

EMSCRIPTEN_KEEPALIVE void TransformPipeline_addKeyBinding(int logicalKey, int intentAction, float value) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto calculator = pipeline->getCalculator();
        if (calculator) {
            auto config = calculator->getConfiguration();
            config.addBinding(static_cast<LogicalKey>(logicalKey), static_cast<IntentAction>(intentAction), value);
            calculator->setConfiguration(config);
            TRACE("[C API] Added key binding: key=%d, action=%d, value=%.2f", logicalKey, intentAction, value);
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_removeKeyBindingsForKey(int logicalKey) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto calculator = pipeline->getCalculator();
        if (calculator) {
            auto config = calculator->getConfiguration();
            config.removeBindingsForKey(static_cast<LogicalKey>(logicalKey));
            calculator->setConfiguration(config);
            TRACE("[C API] Removed key bindings for key=%d", logicalKey);
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_removeKeyBindingsForAction(int intentAction) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto calculator = pipeline->getCalculator();
        if (calculator) {
            auto config = calculator->getConfiguration();
            config.removeBindingsForAction(static_cast<IntentAction>(intentAction));
            calculator->setConfiguration(config);
            TRACE("[C API] Removed key bindings for action=%d", intentAction);
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_clearKeyBindings() {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto calculator = pipeline->getCalculator();
        if (calculator) {
            auto config = calculator->getConfiguration();
            config.clearBindings();
            calculator->setConfiguration(config);
            TRACE("[C API] Cleared all key bindings");
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_addMouseButtonBinding(int mouseButton, int intentAction, float value) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto calculator = pipeline->getCalculator();
        if (calculator) {
            auto config = calculator->getConfiguration();
            config.addMouseButtonBinding(static_cast<MouseButton>(mouseButton), static_cast<IntentAction>(intentAction), value);
            calculator->setConfiguration(config);
            TRACE("[C API] Added mouse button binding: button=%d, action=%d, value=%.2f", mouseButton, intentAction, value);
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_removeMouseButtonBindings(int mouseButton) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto calculator = pipeline->getCalculator();
        if (calculator) {
            auto config = calculator->getConfiguration();
            config.removeBindingsForMouseButton(static_cast<MouseButton>(mouseButton));
            calculator->setConfiguration(config);
            TRACE("[C API] Removed mouse button bindings for button=%d", mouseButton);
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_setMouseSensitivity(float sensitivity) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto calculator = pipeline->getCalculator();
        if (calculator) {
            auto config = calculator->getConfiguration();
            config.mouseSensitivity = sensitivity;
            calculator->setConfiguration(config);
            TRACE("[C API] Set mouse sensitivity to %.3f", sensitivity);
        }
    }
}

EMSCRIPTEN_KEEPALIVE void TransformPipeline_setInvertMouseY(bool invert) {
    auto pipeline = getPipeline();
    if (pipeline) {
        auto calculator = pipeline->getCalculator();
        if (calculator) {
            auto config = calculator->getConfiguration();
            config.invertMouseY = invert;
            calculator->setConfiguration(config);
            TRACE("[C API] Set invert mouse Y to %s", invert ? "true" : "false");
        }
    }
}

}
