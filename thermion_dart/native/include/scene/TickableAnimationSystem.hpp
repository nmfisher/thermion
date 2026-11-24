#pragma once

#include <cstdint>

namespace thermion
{
    /// An animation system driven by AnimationManager::update(). The core
    /// AnimationManager ticks its own morph/bone component managers and any
    /// systems added via addTickable() (e.g. the glTF-only embedded clip
    /// playback in GltfAnimationComponentManager), so optional animation
    /// features can hook into the frame loop without core code depending on
    /// them. The system's owner keeps ownership and must removeTickable()
    /// before destroying it.
    class TickableAnimationSystem
    {
    public:
        virtual ~TickableAnimationSystem() = default;

        /// @param frameTimeInNanos the number of nanoseconds elapsed since
        /// the engine started (same clock as AnimationManager::update).
        virtual void update(uint64_t frameTimeInNanos) = 0;
    };
}
