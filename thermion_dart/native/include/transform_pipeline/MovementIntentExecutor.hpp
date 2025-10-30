#pragma once

#include "MovementIntentCalculator.hpp"
#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <utils/Entity.h>


namespace thermion::plugin::input {


    // Movement space enumeration
    enum class MovementSpace {
        world,
        object
    };

    // Movement configuration structure (separate from intent)
    struct MovementConfig {
        // Movement settings
        double baseMoveSpeed = 50.0;
        double mouseSensitivity = 0.001;
        bool invertHorizontalMovement = false;
        MovementSpace movementSpace = MovementSpace::world;

        // Jump configuration
        double jumpHeight = 10.0;             // How high to jump (units)
        double groundLevel = 0.0;             // Y position considered ground level
    };

    using namespace thermion;
    using namespace filament::math;

    // Pipeline processor for movement intents
    class MovementIntentExecutor {
    public:
        MovementIntentExecutor(filament::Engine* engine);
        virtual ~MovementIntentExecutor() = default;
        
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
        void executeMovement(utils::Entity entity, const MovementIntent& intent);

    };

} // namespace thermion::plugin::input