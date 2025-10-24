#pragma once

#include <cstdint>

// C++ API for plugin system
namespace thermion::plugin {

    /**
     * Update all registered plugin component managers.
     * @param frameTimeInNanos Start time (in nanoseconds) of current frame
     */
    void UpdatePlugins(uint64_t frameTimeInNanos);

    /**
     * Cleanup all plugin component managers.
     */
    void CleanupPlugins();
}

