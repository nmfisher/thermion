#include "Log.hpp"
#include <utils/Entity.h>
#include <filament/Engine.h>
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

EMSCRIPTEN_KEEPALIVE TMovementIntentExecutor* MovementIntentExecutor_createDefault(void* tEngine) {
    auto *engine = reinterpret_cast<filament::Engine*>(tEngine);
    auto *processor = new MovementIntentExecutor(engine);
    auto *tProcessor = reinterpret_cast<TMovementIntentExecutor*>(processor);
    return tProcessor;
}

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

EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_setTargetEntity(TMovementIntentExecutor* tProcessor, uint32_t entityId) {
    auto *processor = reinterpret_cast<MovementIntentExecutor *>(tProcessor);

    auto targetEntity = utils::Entity::import(entityId);
    if(targetEntity.isNull()) {
        ERROR("Target entity is null. This is a big problem");
        return;
    }

    processor->setTargetEntity(targetEntity);

    TRACE("Set target entity for movement executor to %d", entityId);
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
    intent.deltaTime = tIntent->deltaTime;
    intent.hasMovementIntent = tIntent->hasMovementIntent != 0;
    intent.hasRotationIntent = tIntent->hasRotationIntent != 0;

    executor->process(intent, deltaTimeInNanos);
}

EMSCRIPTEN_KEEPALIVE void MovementIntentExecutor_setConfig(TMovementIntentExecutor* tExecutor, TMovementConfig *tConfig) {
    auto *executor = reinterpret_cast<MovementIntentExecutor *>(tExecutor);
    // Convert TMovementConfig C struct to C++ MovementConfig
    MovementConfig config;
    config.baseMoveSpeed = tConfig->baseMoveSpeed;
    config.mouseSensitivity = tConfig->mouseSensitivity;
    config.invertHorizontalMovement = tConfig->invertHorizontalMovement != 0;
    config.movementSpace = static_cast<MovementSpace>(tConfig->movementSpace);
    config.jumpHeight = tConfig->jumpHeight;
    config.groundLevel = tConfig->groundLevel;
    executor->setConfig(config);
}


#ifdef __cplusplus
}
}
#endif