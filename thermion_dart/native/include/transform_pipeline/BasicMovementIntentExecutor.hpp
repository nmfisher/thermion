#pragma once

#include "MovementIntentCalculator.hpp"
#include "MovementIntentExecutor.hpp"
#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <utils/Entity.h>

#ifndef M_PI
    #define M_PI 3.14159265358979323846
#endif

namespace thermion::plugin::input {

    struct MovementConfig {
        double baseMoveSpeed = 50.0;
        double mouseSensitivity = 0.001;
        bool invertHorizontalMovement = false;
        MovementSpace movementSpace = MovementSpace::world;

    };
    
    class BasicMovementIntentExecutor : MovementIntentExecutor{
    public:
        BasicMovementIntentExecutor(filament::Engine* engine);
        virtual ~BasicMovementIntentExecutor() = default;
        
        virtual void process(const MovementIntent& intent, uint64_t deltaTimeInNanos);
        
        const MovementConfig& getConfig() {
            return mConfig;
        }

        void setConfig(const MovementConfig& config) {
            mConfig = config;
        }

        utils::Entity getTargetEntity() const;
        void setTargetEntity(utils::Entity entity);

    private:
        filament::TransformManager* mTransformManager;
        utils::Entity mTargetEntity;
        MovementConfig mConfig;
        
        bool canExecuteMovement(utils::Entity entity) const;

    };

} // namespace thermion::plugin::input