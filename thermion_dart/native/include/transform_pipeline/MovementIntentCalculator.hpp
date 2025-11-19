#pragma once

#include <math/vec3.h>
#include <math/vec2.h>
#include "InputEventManager.hpp"
#include "InputConfiguration.hpp"
#include "MovementIntent.hpp"

namespace thermion::plugin::input {

    using namespace thermion;
    using namespace filament::math;

    /**
     * Calculator that converts raw input and configuration into movement intents.
     * Can be configured at runtime to support different keybinding schemes.
     */
    class MovementIntentCalculator {
    private:
        InputConfiguration config_;

    public:
        /**
         * Construct with default WASD configuration.
         */
        MovementIntentCalculator()
            : config_(createDefaultConfiguration()) {}

        /**
         * Construct with custom configuration.
         */
        explicit MovementIntentCalculator(const InputConfiguration& config)
            : config_(config) {}

        ~MovementIntentCalculator() = default;

        /**
         * Update configuration at runtime.
         */
        void setConfiguration(const InputConfiguration& config) {
            config_ = config;
        }

        /**
         * Get current configuration.
         */
        const InputConfiguration& getConfiguration() const {
            return config_;
        }

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