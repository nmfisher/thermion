#pragma once

// C++ API for plugin system
namespace thermion {


    /**
     * Update all registered plugin component managers.
     * @param deltaTime Time elapsed since last frame in seconds
     */
    void UpdatePluginComponentManagers(float deltaTime);

    /**
     * Cleanup all plugin component managers.
     */
    void CleanupPluginComponentManagers();
}

