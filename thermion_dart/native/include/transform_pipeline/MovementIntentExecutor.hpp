#pragma once

#include "MovementIntentCalculator.hpp"
#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <utils/Entity.h>


namespace thermion::plugin::input {

    using namespace thermion;
    using namespace filament::math;

    // Pipeline processor for movement intents
    class MovementIntentExecutor {
    public:
        MovementIntentExecutor(filament::Engine* engine);
        virtual ~MovementIntentExecutor() = default;
        
        virtual void process(const MovementIntent& intent, const MovementConfig& config, uint64_t deltaTimeInNanos);

        utils::Entity getTargetEntity() const;
        void setTargetEntity(utils::Entity entity);

    private:
        filament::TransformManager* mTransformManager;
        utils::Entity mTargetEntity;
        bool canExecuteMovement(utils::Entity entity) const;
        void executeMovement(utils::Entity entity, const MovementIntent& intent, const MovementConfig& config);

    };

} // namespace thermion::plugin::input