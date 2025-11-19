#include "transform_pipeline/MovementIntentCalculator.hpp"
#include "Log.hpp"
#include <cmath>

namespace thermion::plugin::input
{
    using namespace thermion;

    MovementIntent MovementIntentCalculator::calculate(
        const InputState& inputState,
        uint64_t deltaTimeInNanos
    ) const
    {

        MovementIntent intent;

        // Calculate movement direction from configured keybindings
        float3 movementDirection = {0, 0, 0};
        const uint64_t pressedKeys = inputState.pressedKeys;

        // Debug: Count pressed keys for logging
        uint32_t numPressedKeys = __builtin_popcountll(pressedKeys);
        TRACE("[MovementIntentCalculator] Processing %u pressed keys (bitmask: 0x%016llx)",
              numPressedKeys, static_cast<unsigned long long>(pressedKeys));

        // Process all configured keybindings
        for (const auto& binding : config_.keyBindings)
        {
            if (isKeyPressed(pressedKeys, binding.key))
            {
                switch (binding.action)
                {
                    case IntentAction::MoveForward:
                        movementDirection.z += binding.value;
                        TRACE("[MovementIntentCalculator] MoveForward key pressed, adding forward movement (%.2f)", binding.value);
                        break;

                    case IntentAction::MoveBackward:
                        movementDirection.z -= binding.value;
                        TRACE("[MovementIntentCalculator] MoveBackward key pressed, adding backward movement (%.2f)", binding.value);
                        break;

                    case IntentAction::MoveLeft:
                        movementDirection.x += binding.value;
                        TRACE("[MovementIntentCalculator] MoveLeft key pressed, adding left movement (%.2f)", binding.value);
                        break;

                    case IntentAction::MoveRight:
                        movementDirection.x -= binding.value;
                        TRACE("[MovementIntentCalculator] MoveRight key pressed, adding right movement (%.2f)", binding.value);
                        break;

                    case IntentAction::Jump:
                        intent.setJumpIntent(true);
                        TRACE("[MovementIntentCalculator] Jump intent activated");
                        break;

                    case IntentAction::Sprint:
                        intent.setSprintIntent(true);
                        TRACE("[MovementIntentCalculator] Sprint intent activated");
                        break;

                    default:
                        // Store all other intents as custom intents using array indexing
                        intent.setCustomIntent(binding.action, binding.value);
                        TRACE("[MovementIntentCalculator] Custom intent %d activated with value %.2f",
                              static_cast<int>(binding.action), binding.value);
                        break;
                }
            }
        }

        // Normalize movement direction and apply speed
        if (length(movementDirection) > 0.0f)
        {
            intent.movementDirection = normalize(movementDirection);
            intent.movementSpeed = 1.0f; // Full speed when moving
            intent.setMovementIntent(true);

            TRACE("[MovementIntentCalculator] Movement intent: direction(%.3f, %.3f, %.3f), speed: %.3f",
                  intent.movementDirection.x, intent.movementDirection.y, intent.movementDirection.z,
                  intent.movementSpeed);
        }
        else
        {
            intent.movementDirection = {0, 0, 0};
            intent.movementSpeed = 0.0f;
            intent.setMovementIntent(false);
            TRACE("[MovementIntentCalculator] No movement intent - no movement keys pressed");
        }

        // Calculate rotation intent from mouse delta
        float mouseDeltaLength = length(inputState.mouseDelta);
        if (mouseDeltaLength > 0.0f)
        {
            // Apply mouse sensitivity and inversion settings
            float2 adjustedDelta = inputState.mouseDelta * config_.mouseSensitivity;
            if (config_.invertMouseY)
            {
                adjustedDelta.y = -adjustedDelta.y;
            }

            intent.mouseDelta = adjustedDelta;
            intent.setRotationIntent(true);

            TRACE("[MovementIntentCalculator] Rotation intent: delta(%.3f, %.3f), length: %.6f",
                  intent.mouseDelta.x, intent.mouseDelta.y, mouseDeltaLength);
        }
        else
        {
            intent.mouseDelta = {0, 0};
            intent.setRotationIntent(false);
            TRACE("[MovementIntentCalculator] No rotation intent - mouse delta too small");
        }

        return intent;
    }

} // namespace thermion::plugin::input