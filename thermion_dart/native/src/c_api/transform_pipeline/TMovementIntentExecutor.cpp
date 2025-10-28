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

EMSCRIPTEN_KEEPALIVE TMovementIntentExecutor* create_default_transform_executor(void* tEngine) {
    auto *engine = reinterpret_cast<filament::Engine*>(tEngine);
    auto *processor = new MovementIntentExecutor(engine);
    auto *tProcessor = reinterpret_cast<TMovementIntentExecutor*>(processor);
    return tProcessor;
}

EMSCRIPTEN_KEEPALIVE void movement_intent_executor_destroy(TMovementIntentExecutor* tProcessor) {
    auto *processor = reinterpret_cast<MovementIntentExecutor *>(tProcessor);
    delete processor;
}

EMSCRIPTEN_KEEPALIVE void pipeline_register_movement_intent_executor(TMovementIntentExecutor* tProcessor) {
    auto pipeline = getPipeline();
    if (pipeline && tProcessor) {
        auto *processor = reinterpret_cast<MovementIntentExecutor *>(tProcessor);
        pipeline->registerMovementIntentExecutor(processor);
        TRACE("[C API] Registered movement intent processor with pipeline");
    } else {
        TRACE("[C API] Failed to register movement intent processor - pipeline or processor is null");
    }
}

EMSCRIPTEN_KEEPALIVE void movement_intent_executor_set_target_entity(TMovementIntentExecutor* tProcessor, uint32_t entityId) {
    auto *processor = reinterpret_cast<MovementIntentExecutor *>(tProcessor);

    auto targetEntity = utils::Entity::import(entityId);    
    if(targetEntity.isNull()) {
        ERROR("Target entity is null. This is a big problem");
        return;
    }

    processor->setTargetEntity(targetEntity);

    TRACE("Set target entiyt for movement executor to %d", entityId);
}

#ifdef __cplusplus
}
}
#endif