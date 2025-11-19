#pragma once

#include <math/vec3.h>
#include <math/vec2.h>
#include <array>
#include "InputEventManager.hpp"
#include "InputConfiguration.hpp"

namespace thermion::plugin::input {

    using namespace thermion;
    using namespace filament::math;

    // Maximum number of IntentAction values for fixed-size array
    // Update this if IntentAction enum grows beyond this size
    constexpr size_t MAX_INTENT_ACTIONS = 64;

    // Input state structure for read-only access
    struct InputState {
        uint64_t pressedKeys;
        const float2& mouseDelta;
    };

    // Intent state bitmasks (first 4 bits for standard intents, remaining 28 for custom)
    // Undefine any potential macros from C API headers to avoid conflicts
    #ifdef MOVEMENT_INTENT_MASK
    #undef MOVEMENT_INTENT_MASK
    #endif
    #ifdef ROTATION_INTENT_MASK
    #undef ROTATION_INTENT_MASK
    #endif
    #ifdef JUMP_INTENT_MASK
    #undef JUMP_INTENT_MASK
    #endif
    #ifdef SPRINT_INTENT_MASK
    #undef SPRINT_INTENT_MASK
    #endif

    constexpr uint32_t MOVEMENT_INTENT_MASK = 0x00000001;  // bit 0
    constexpr uint32_t ROTATION_INTENT_MASK = 0x00000002;  // bit 1
    constexpr uint32_t JUMP_INTENT_MASK     = 0x00000004;  // bit 2
    constexpr uint32_t SPRINT_INTENT_MASK   = 0x00000008;  // bit 3
    constexpr uint32_t CUSTOM_INTENT_START  = 4;           // bits 4-31 for custom intents

    // Movement intent structure - represents what the player wants to do this frame
    struct MovementIntent {
        float3 movementDirection = {0, 0, 0};  // Normalized direction vector
        float movementSpeed = 0.0f;           // Current speed multiplier (0-1)
        float2 mouseDelta = {0, 0};          // Camera rotation intent

        // Intent state bitmask (32 bits: first 4 for standard intents, remaining 28 for custom)
        uint32_t intentStates = 0;

        // Fixed-size array for custom intents (indexed by IntentAction)
        // Value of 0.0f indicates intent is not active
        std::array<float, MAX_INTENT_ACTIONS> customIntents = {};

        // Movement intent accessors
        inline bool hasMovementIntent() const {
            return (intentStates & MOVEMENT_INTENT_MASK) != 0;
        }

        inline void setMovementIntent(bool value) {
            if (value) {
                intentStates |= MOVEMENT_INTENT_MASK;
            } else {
                intentStates &= ~MOVEMENT_INTENT_MASK;
            }
        }

        // Rotation intent accessors
        inline bool hasRotationIntent() const {
            return (intentStates & ROTATION_INTENT_MASK) != 0;
        }

        inline void setRotationIntent(bool value) {
            if (value) {
                intentStates |= ROTATION_INTENT_MASK;
            } else {
                intentStates &= ~ROTATION_INTENT_MASK;
            }
        }

        // Jump intent accessors
        inline bool hasJumpIntent() const {
            return (intentStates & JUMP_INTENT_MASK) != 0;
        }

        inline void setJumpIntent(bool value) {
            if (value) {
                intentStates |= JUMP_INTENT_MASK;
            } else {
                intentStates &= ~JUMP_INTENT_MASK;
            }
        }

        // Sprint intent accessors
        inline bool hasSprintIntent() const {
            return (intentStates & SPRINT_INTENT_MASK) != 0;
        }

        inline void setSprintIntent(bool value) {
            if (value) {
                intentStates |= SPRINT_INTENT_MASK;
            } else {
                intentStates &= ~SPRINT_INTENT_MASK;
            }
        }

        /**
         * Check if a custom intent is active.
         */
        bool hasCustomIntent(IntentAction action) const {
            size_t index = static_cast<size_t>(action);
            return index < MAX_INTENT_ACTIONS && customIntents[index] != 0.0f;
        }

        /**
         * Get the value of a custom intent (returns 0.0f if not present).
         */
        float getCustomIntentValue(IntentAction action) const {
            size_t index = static_cast<size_t>(action);
            return index < MAX_INTENT_ACTIONS ? customIntents[index] : 0.0f;
        }

        /**
         * Set a custom intent value.
         */
        void setCustomIntent(IntentAction action, float value) {
            size_t index = static_cast<size_t>(action);
            if (index < MAX_INTENT_ACTIONS) {
                customIntents[index] = value;
            }
        }

        /**
         * Clear a custom intent.
         */
        void clearCustomIntent(IntentAction action) {
            size_t index = static_cast<size_t>(action);
            if (index < MAX_INTENT_ACTIONS) {
                customIntents[index] = 0.0f;
            }
        }
    };


} // namespace thermion::plugin::input