#pragma once

// C++ API for plugin system
namespace thermion::plugin {

    /**
     * Update all registered plugin component managers.
     * @param deltaTime Time elapsed since last frame in seconds
     */
    void UpdatePlugins(float deltaTime);

    /**
     * Cleanup all plugin component managers.
     */
    void CleanupPlugins();
}

