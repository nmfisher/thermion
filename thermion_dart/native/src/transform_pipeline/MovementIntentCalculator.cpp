#include "transform_pipeline/MovementIntentCalculator.hpp"
#include "Log.hpp"
#include <cmath>

namespace thermion::plugin::input
{
    using namespace thermion;

    MovementIntent MovementIntentCalculator::calculate(
        const InputState& inputState,
        const MovementConfig& config,
        uint64_t deltaTimeInNanos
    ) const
    {
        // Convert nanoseconds to seconds for MovementIntent
        float deltaTime = deltaTimeInNanos / 1'000'000'000.0f;
        TRACE("[MovementIntentCalculator] Creating intent with deltaTime=%.6f seconds (%llu nanoseconds)",
              deltaTime, deltaTimeInNanos);

        MovementIntent intent;
        intent.deltaTime = deltaTime;

        // Note: Configuration values are NOT copied to MovementIntent
        // MovementIntent only contains the calculated intent (what to do)
        // Configuration stays with the MovementConfig and is used by MovementExecutor

        // Calculate movement direction from pressed keys
        float3 movementDirection = {0, 0, 0};
        const auto& pressedKeys = inputState.pressedKeys;

        // Debug: Log current pressed keys
        TRACE("[MovementIntentCalculator] Processing %zu pressed keys", pressedKeys.size());
        if (pressedKeys.size() > 0)
        {
            for (const auto& key : pressedKeys)
            {
                TRACE("[MovementIntentCalculator]   - Pressed key: %d", static_cast<int>(key));
            }
        }

        // WASD movement
        if (pressedKeys.count(LogicalKey::w))
        {
            movementDirection.z += 1.0f; // Forward
            TRACE("[MovementIntentCalculator] W key pressed, adding forward movement");
        }
        if (pressedKeys.count(LogicalKey::s))
        {
            movementDirection.z -= 1.0f; // Backward
            TRACE("[MovementIntentCalculator] S key pressed, adding backward movement");
        }

        if (pressedKeys.count(LogicalKey::a))
        {
            movementDirection.x += 1.0f; // Left
            TRACE("[MovementIntentCalculator] A key pressed, adding left movement");
        }
        if (pressedKeys.count(LogicalKey::d))
        {
            movementDirection.x -= 1.0f; // Right
            TRACE("[MovementIntentCalculator] D key pressed, adding right movement");
        }

        // Normalize movement direction and apply speed
        if (length(movementDirection) > 0.0f)
        {
            intent.movementDirection = normalize(movementDirection);
            intent.movementSpeed = 1.0f; // Full speed when moving
            intent.hasMovementIntent = true;

            TRACE("[MovementIntentCalculator] Movement intent: direction(%.3f, %.3f, %.3f), speed: %.3f",
                  intent.movementDirection.x, intent.movementDirection.y, intent.movementDirection.z,
                  intent.movementSpeed);
        }
        else
        {
            intent.movementDirection = {0, 0, 0};
            intent.movementSpeed = 0.0f;
            intent.hasMovementIntent = false;
            TRACE("[MovementIntentCalculator] No movement intent - no movement keys pressed");
        }

        // Calculate rotation intent from mouse delta
        float mouseDeltaLength = length(inputState.mouseDelta);
        if (mouseDeltaLength > 0.0f)
        {
            intent.mouseDelta = inputState.mouseDelta;
            intent.hasRotationIntent = true;

            TRACE("[MovementIntentCalculator] Rotation intent: delta(%.3f, %.3f), length: %.6f",
                  intent.mouseDelta.x, intent.mouseDelta.y, mouseDeltaLength);
        }
        else
        {
            intent.mouseDelta = {0, 0};
            intent.hasRotationIntent = false;
            TRACE("[MovementIntentCalculator] No rotation intent - mouse delta too small");
        }

        // Jump and sprint intent
        intent.jumpIntent = pressedKeys.count(LogicalKey::space) > 0;
        intent.sprintIntent = pressedKeys.count(LogicalKey::shift) > 0;

        TRACE("[MovementIntentCalculator] Final intent - deltaTime=%.6f, hasMovement=%s, hasRotation=%s, jump=%s, sprint=%s",
              deltaTime,
              intent.hasMovementIntent ? "true" : "false",
              intent.hasRotationIntent ? "true" : "false",
              intent.jumpIntent ? "true" : "false",
              intent.sprintIntent ? "true" : "false");

        return intent;
    }

} // namespace thermion::plugin::input