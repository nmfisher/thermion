#include "PluginAPI.hpp"
#include "IPluginComponentManager.hpp"
#include <vector>
#include <memory>
#include <map>
#include <functional>
#include <string>

#include "Log.hpp"

namespace thermion
{

    namespace
    {
        std::vector<IPluginComponentManager *> g_registeredComponentManagers;
    }

    /**
     * Register a component manager instance directly.
     * This is called by plugins during static initialization to register themselves.
     */
    bool RegisterComponentManager(const std::string &name, IPluginComponentManager *instance)
    {
        if (!instance)
        {

            Log("[PLUGIN] Error: Cannot register null component manager for '%s'", name.c_str());

            return false;
        }


        g_registeredComponentManagers.push_back(instance);

        Log("[PLUGIN] Registered component manager instance: %s (%d plugins total)", name.c_str(), g_registeredComponentManagers.size());

        return true;
    }

    /**
     * Update all registered plugin component managers.
     * This is called from thermion's main render loop.
     */
    void UpdatePluginComponentManagers(float deltaTime)
    {
        Log("Updating %d component managers", g_registeredComponentManagers.size());
        for (auto *manager : g_registeredComponentManagers)
        {
            manager->update(deltaTime);
        }
    }

    /**
     * Cleanup all plugin component managers.
     */
    void CleanupPluginComponentManagers()
    {
        for (auto *manager : g_registeredComponentManagers)
        {
            manager->cleanup();
        }
        g_registeredComponentManagers.clear();
    }

} // namespace thermion
