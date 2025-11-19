#include <filament/TransformManager.h>
#include <filament/Engine.h>

#include <math/mat4.h>
#include <cmath>

#include "transform_pipeline/BasicMovementIntentExecutor.hpp"
#include "Log.hpp"

namespace thermion::plugin::input
{

    using namespace thermion;

    BasicMovementIntentExecutor::BasicMovementIntentExecutor(filament::Engine *engine)
        : mTransformManager(&engine->getTransformManager())
    {
        TRACE("[BasicMovementIntentExecutor] Created with transform manager from engine");
    }

    void BasicMovementIntentExecutor::setTargetEntity(utils::Entity entity)
    {
        mTargetEntity = entity;
        TRACE("[BasicMovementIntentExecutor] Set target entity to %d", utils::Entity::smuggle(entity));
    }

    void BasicMovementIntentExecutor::process(const MovementIntent &intent, uint64_t deltaTimeInNanos)
    {
        TRACE("[BasicMovementIntentExecutor] Processing single movement intent with delta time: %llu nanoseconds", deltaTimeInNanos);

        if (!mTransformManager)
        {
            TRACE("[BasicMovementIntentExecutor] ERROR: No transform manager available");
            return;
        }

        auto transformInstance = mTransformManager->getInstance(mTargetEntity);
        if (!transformInstance.isValid())
        {
            TRACE("[BasicMovementIntentExecutor] ERROR: Invalid transform instance for entity %d", mTargetEntity.getId());
            return;
        }

        // Get current transform and position
        auto currentTransform = mTransformManager->getTransform(transformInstance);
        auto currentPosition = filament::math::float3{
            currentTransform[3][0],
            currentTransform[3][1],
            currentTransform[3][2]};

        TRACE("[BasicMovementIntentExecutor] Entity %d: current position(%.6f, %.6f, %.6f)",
              mTargetEntity.getId(), currentPosition.x, currentPosition.y, currentPosition.z);

        // Calculate movement delta
        float3 movementDelta = {0, 0, 0};
        // Convert nanoseconds to seconds for MovementIntent
        float deltaTime = deltaTimeInNanos / 1'000'000'000.0f;
        TRACE("[MovementIntentCalculator] Creating intent with deltaTime=%.6f seconds (%llu nanoseconds)",
              deltaTime, deltaTimeInNanos);

        if (intent.hasMovementIntent())
        {

            float movementAmount = static_cast<float>(mConfig.baseMoveSpeed * intent.movementSpeed * deltaTime);
            movementDelta = intent.movementDirection * movementAmount;

            TRACE("[BasicMovementIntentExecutor] Entity %d MOVEMENT CALCULATION:", mTargetEntity.getId());
            TRACE("[BasicMovementIntentExecutor]   - deltaTime: %.6f seconds", deltaTime);
            TRACE("[BasicMovementIntentExecutor]   - baseMoveSpeed: %.2f units/s", mConfig.baseMoveSpeed);
            TRACE("[BasicMovementIntentExecutor]   - movementSpeed: %.3f (multiplier)", intent.movementSpeed);
            TRACE("[BasicMovementIntentExecutor]   - movementAmount: %.6f units (%.2f * %.3f * %.6f)",
                  movementAmount, mConfig.baseMoveSpeed, intent.movementSpeed, deltaTime);
            TRACE("[BasicMovementIntentExecutor]   - direction: (%.3f, %.3f, %.3f)",
                  intent.movementDirection.x, intent.movementDirection.y, intent.movementDirection.z);
            TRACE("[BasicMovementIntentExecutor]   - final movement delta: (%.6f, %.6f, %.6f)",
                  movementDelta.x, movementDelta.y, movementDelta.z);
        }
        else
        {
            TRACE("[BasicMovementIntentExecutor] Entity %d: No movement intent", mTargetEntity.getId());
        }

        // Calculate rotation from mouse delta
        filament::math::mat4f rotationMatrix = filament::math::mat4f{};
        if (intent.hasRotationIntent())
        {
            float horizontalMouseDelta = intent.mouseDelta.x;
            if (mConfig.invertHorizontalMovement)
            {
                horizontalMouseDelta *= -1.0f;
            }

            float yaw = horizontalMouseDelta * static_cast<float>(mConfig.mouseSensitivity);
            rotationMatrix = filament::math::mat4f::rotation(yaw, filament::math::float3{0, 1, 0});

            TRACE("[BasicMovementIntentExecutor] Entity %d ROTATION:", mTargetEntity.getId());
            TRACE("[BasicMovementIntentExecutor]   - mouseDelta.x: %.3f pixels", intent.mouseDelta.x);
            TRACE("[BasicMovementIntentExecutor]   - invertHorizontal: %s", mConfig.invertHorizontalMovement ? "true" : "false");
            TRACE("[BasicMovementIntentExecutor]   - mouseSensitivity: %.6f", mConfig.mouseSensitivity);
            TRACE("[BasicMovementIntentExecutor]   - horizontalMouseDelta: %.3f", horizontalMouseDelta);
            TRACE("[BasicMovementIntentExecutor]   - yaw radians: %.6f degrees: %.3f", yaw, yaw * 180.0f / M_PI);
        }

        // Apply transform if there's movement, rotation, or jumping
        if (intent.hasMovementIntent() || intent.hasRotationIntent() || intent.hasJumpIntent())
        {
            auto translation = filament::math::mat4f::translation(movementDelta);
            auto newTransform = currentTransform * translation * rotationMatrix;

            // Extract new position for logging
            auto newPosition = filament::math::float3{
                newTransform[3][0],
                newTransform[3][1],
                newTransform[3][2]};

            // Calculate actual position change
            auto positionChange = newPosition - currentPosition;

            mTransformManager->setTransform(transformInstance, newTransform);

            TRACE("[BasicMovementIntentExecutor] Entity %d TRANSFORM APPLIED:", mTargetEntity.getId());
            TRACE("[BasicMovementIntentExecutor]   - position change: (%.6f, %.6f, %.6f)",
                  positionChange.x, positionChange.y, positionChange.z);
            TRACE("[BasicMovementIntentExecutor]   - old position: (%.6f, %.6f, %.6f)",
                  currentPosition.x, currentPosition.y, currentPosition.z);
            TRACE("[BasicMovementIntentExecutor]   - new position: (%.6f, %.6f, %.6f)",
                  newPosition.x, newPosition.y, newPosition.z);
            TRACE("[BasicMovementIntentExecutor]   - total distance moved: %.6f units",
                  length(positionChange));
        }
        else
        {
            TRACE("[BasicMovementIntentExecutor] Entity %d: No transform applied (no movement or rotation)", mTargetEntity.getId());
        }
    }

    bool BasicMovementIntentExecutor::canExecuteMovement(utils::Entity entity) const
    {
        if (!mTransformManager)
        {
            return false;
        }

        auto transformInstance = mTransformManager->getInstance(entity);
        return transformInstance.isValid();
    }

    utils::Entity BasicMovementIntentExecutor::getTargetEntity() const
    {
        return mTargetEntity;
    }

} // namespace thermion::plugin::input