#pragma once

#include <math/vec3.h>
#include <math/vec2.h>
#include <unordered_set>
#include "InputEventManager.hpp"

namespace thermion::plugin::input {

    using namespace thermion;
    using namespace filament::math;

    // Input state structure for read-only access
    struct InputState {
        const std::unordered_set<LogicalKey>& pressedKeys;
        const float2& mouseDelta;
    };

    // Movement intent structure - represents what the player wants to do this frame
    struct MovementIntent {
        float3 movementDirection = {0, 0, 0};  // Normalized direction vector
        float movementSpeed = 0.0f;           // Current speed multiplier (0-1)
        float2 mouseDelta = {0, 0};          // Camera rotation intent
        bool jumpIntent = false;
        bool sprintIntent = false;
        bool hasMovementIntent = false;
        bool hasRotationIntent = false;
    };

    /**
     * Stateless calculator that converts raw input and configuration into movement intents.
     * This class has no internal state and simply performs calculations based on provided inputs.
     */
    class MovementIntentCalculator {
    public:
        MovementIntentCalculator() = default;
        ~MovementIntentCalculator() = default;

        /**
         * Calculate movement intent based on input state, configuration, and delta time.
         *
         * @param inputState Current input state (pressed keys, mouse delta)
         * @param deltaTimeInNanos Time since last frame in nanoseconds
         * @return MovementIntent Calculated movement intent for this frame
         */
        MovementIntent calculate(
            const InputState& inputState,
            uint64_t deltaTimeInNanos
        ) const;
    };

} // namespace thermion::plugin::input