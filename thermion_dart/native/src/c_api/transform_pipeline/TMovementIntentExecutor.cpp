#include <utils/Entity.h>
#include <filament/Engine.h>

#include "Log.hpp"
#include "c_api/transform_pipeline/TMovementIntentExecutor.h"
#include "transform_pipeline/MovementIntentExecutor.hpp"
#include "transform_pipeline/Pipeline.hpp"
#include "transform_pipeline/InputEventManager.hpp"
#include "transform_pipeline/MovementIntentCalculator.hpp"

/**
 * Public C API functions for Movement Intent Processor Dart FFI integration.
 * Bridges the C interface to the C++ MovementIntentExecutor.
 */

#ifdef __cplusplus
extern "C" {
namespace thermion::plugin::input {
#endif

using namespace thermion;

EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_destroy(TMovementIntentExecutor* tProcessor) {
    auto *processor = reinterpret_cast<MovementIntentExecutor *>(tProcessor);
    delete processor;
}

EMSCRIPTEN_KEEPALIVE void Pipeline_registerMovementIntentExecutor(TMovementIntentExecutor* tProcessor) {
    auto pipeline = getPipeline();
    auto *processor = reinterpret_cast<MovementIntentExecutor *>(tProcessor);
    if (pipeline) {
        pipeline->registerMovementIntentExecutor(processor);
        TRACE("[C API] Registered movement intent processor with pipeline");
    } else {
        TRACE("[C API] Failed to register movement intent processor - pipeline or processor is null");
    }
}

EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_process(
    TMovementIntentExecutor* tExecutor,
    const TMovementIntent* tIntent,
    uint64_t deltaTimeInNanos
) {
    auto *executor = reinterpret_cast<MovementIntentExecutor *>(tExecutor);

    // Convert TMovementIntent C struct to C++ MovementIntent
    MovementIntent intent;
    intent.movementDirection = {tIntent->movementDirectionX, tIntent->movementDirectionY, tIntent->movementDirectionZ};
    intent.movementSpeed = tIntent->movementSpeed;
    intent.mouseDelta = {tIntent->mouseDeltaX, tIntent->mouseDeltaY};
    intent.jumpIntent = tIntent->jumpIntent != 0;
    intent.sprintIntent = tIntent->sprintIntent != 0;
    intent.hasMovementIntent = tIntent->hasMovementIntent != 0;
    intent.hasRotationIntent = tIntent->hasRotationIntent != 0;

    executor->process(intent, deltaTimeInNanos);
}


#ifdef __cplusplus
}
}
#endif