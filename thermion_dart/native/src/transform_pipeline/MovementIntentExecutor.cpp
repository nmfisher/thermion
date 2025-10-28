#include <filament/TransformManager.h>
#include <filament/Engine.h>

#include <math/mat4.h>
#include <cmath>

#include "transform_pipeline/MovementIntentExecutor.hpp"
#include "Log.hpp"

namespace thermion::plugin::input {

    using namespace thermion;

    MovementIntentExecutor::MovementIntentExecutor(filament::Engine *engine)
        : mTransformManager(&engine->getTransformManager())
    {
        TRACE("[MovementIntentExecutor] Created with transform manager from engine");
    }

    void MovementIntentExecutor::setTargetEntity(utils::Entity entity)
    {
        mTargetEntity = entity;
    }

    void MovementIntentExecutor::process(const MovementIntent& intent, const MovementConfig& config, uint64_t deltaTimeInNanos)
    {
        TRACE("[MovementIntentExecutor] Processing single movement intent with delta time: %llu nanoseconds", deltaTimeInNanos);

        if (!mTransformManager) {
            TRACE("[MovementIntentExecutor] ERROR: No transform manager available");
            return;
        }

        utils::Entity targetEntity = getTargetEntity();
        executeMovement(targetEntity, intent, config);
    }

    bool MovementIntentExecutor::canExecuteMovement(utils::Entity entity) const
    {
        if (!mTransformManager) {
            return false;
        }

        auto transformInstance = mTransformManager->getInstance(entity);
        return transformInstance.isValid();
    }

    void MovementIntentExecutor::executeMovement(utils::Entity entity, const MovementIntent& intent, const MovementConfig& config)
    {
        if (!mTransformManager) {
            Log("[MovementIntentExecutor] ERROR: No transform manager available");
            return;
        }

        auto transformInstance = mTransformManager->getInstance(entity);
        if (!transformInstance.isValid()) {
            TRACE("[MovementIntentExecutor] ERROR: Invalid transform instance for entity %d", entity.getId());
            return;
        }

        // Get current transform and position
        auto currentTransform = mTransformManager->getTransform(transformInstance);
        auto currentPosition = filament::math::float3{
            currentTransform[3][0],
            currentTransform[3][1],
            currentTransform[3][2]
        };

        TRACE("[MovementIntentExecutor] Entity %d: current position(%.6f, %.6f, %.6f)",
              entity.getId(), currentPosition.x, currentPosition.y, currentPosition.z);

        // Calculate movement delta
        float3 movementDelta = {0, 0, 0};
        if (intent.hasMovementIntent) {
            float movementAmount = static_cast<float>(config.baseMoveSpeed * intent.movementSpeed * intent.deltaTime);
            movementDelta = intent.movementDirection * movementAmount;

            TRACE("[MovementIntentExecutor] Entity %d MOVEMENT CALCULATION:", entity.getId());
            TRACE("[MovementIntentExecutor]   - deltaTime: %.6f seconds", intent.deltaTime);
            TRACE("[MovementIntentExecutor]   - baseMoveSpeed: %.2f units/s", config.baseMoveSpeed);
            TRACE("[MovementIntentExecutor]   - movementSpeed: %.3f (multiplier)", intent.movementSpeed);
            TRACE("[MovementIntentExecutor]   - movementAmount: %.6f units (%.2f * %.3f * %.6f)",
                  movementAmount, config.baseMoveSpeed, intent.movementSpeed, intent.deltaTime);
            TRACE("[MovementIntentExecutor]   - direction: (%.3f, %.3f, %.3f)",
                  intent.movementDirection.x, intent.movementDirection.y, intent.movementDirection.z);
            TRACE("[MovementIntentExecutor]   - final movement delta: (%.6f, %.6f, %.6f)",
                  movementDelta.x, movementDelta.y, movementDelta.z);
        } else {
            TRACE("[MovementIntentExecutor] Entity %d: No movement intent", entity.getId());
        }

        // Calculate rotation from mouse delta
        filament::math::mat4f rotationMatrix = filament::math::mat4f{};
        if (intent.hasRotationIntent) {
            float horizontalMouseDelta = intent.mouseDelta.x;
            if (config.invertHorizontalMovement) {
                horizontalMouseDelta *= -1.0f;
            }

            float yaw = horizontalMouseDelta * static_cast<float>(config.mouseSensitivity);
            rotationMatrix = filament::math::mat4f::rotation(yaw, filament::math::float3{0, 1, 0});

            TRACE("[MovementIntentExecutor] Entity %d ROTATION:", entity.getId());
            TRACE("[MovementIntentExecutor]   - mouseDelta.x: %.3f pixels", intent.mouseDelta.x);
            TRACE("[MovementIntentExecutor]   - invertHorizontal: %s", config.invertHorizontalMovement ? "true" : "false");
            TRACE("[MovementIntentExecutor]   - mouseSensitivity: %.6f", config.mouseSensitivity);
            TRACE("[MovementIntentExecutor]   - horizontalMouseDelta: %.3f", horizontalMouseDelta);
            TRACE("[MovementIntentExecutor]   - yaw radians: %.6f degrees: %.3f", yaw, yaw * 180.0f / M_PI);
        }

        // Apply transform if there's movement, rotation, or jumping
        if (intent.hasMovementIntent || intent.hasRotationIntent || intent.jumpIntent) {
            auto translation = filament::math::mat4f::translation(movementDelta);
            auto newTransform = currentTransform * translation * rotationMatrix;

            // Extract new position for logging
            auto newPosition = filament::math::float3{
                newTransform[3][0],
                newTransform[3][1],
                newTransform[3][2]
            };

            // Calculate actual position change
            auto positionChange = newPosition - currentPosition;

            mTransformManager->setTransform(transformInstance, newTransform);

            TRACE("[MovementIntentExecutor] Entity %d TRANSFORM APPLIED:", entity.getId());
            TRACE("[MovementIntentExecutor]   - position change: (%.6f, %.6f, %.6f)",
                  positionChange.x, positionChange.y, positionChange.z);
            TRACE("[MovementIntentExecutor]   - old position: (%.6f, %.6f, %.6f)",
                  currentPosition.x, currentPosition.y, currentPosition.z);
            TRACE("[MovementIntentExecutor]   - new position: (%.6f, %.6f, %.6f)",
                  newPosition.x, newPosition.y, newPosition.z);
            TRACE("[MovementIntentExecutor]   - total distance moved: %.6f units",
                  length(positionChange));
        } else {
            TRACE("[MovementIntentExecutor] Entity %d: No transform applied (no movement or rotation)", entity.getId());
        }
    }

    utils::Entity MovementIntentExecutor::getTargetEntity() const
    {
        return mTargetEntity;
    }

} // namespace thermion::plugin::input