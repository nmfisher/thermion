#pragma once

#include "MovementIntentCalculator.hpp"
#include <filament/Engine.h>
#include <filament/TransformManager.h>
#include <utils/Entity.h>

namespace thermion::plugin::input {
    
    using namespace thermion;
    using namespace filament::math;

    enum class MovementSpace {
        world,
        object
    };

    class MovementIntentExecutor {
        public:
            MovementIntentExecutor() = default;
            virtual ~MovementIntentExecutor() = default;

            virtual void process(const MovementIntent& intent, uint64_t deltaTimeInNanos) = 0;
    };

} // namespace thermion::plugin::input