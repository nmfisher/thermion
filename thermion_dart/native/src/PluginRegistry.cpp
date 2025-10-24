#include "PluginAPI.hpp"
#include "Plugin.hpp"
#include <vector>
#include <memory>
#include <map>
#include <functional>
#include <string>

#include "Log.hpp"

namespace thermion::plugin
{

    namespace
    {
        std::vector<Plugin *> registeredPlugins;
    }

    /**
     * Register a component manager instance directly.
     * This is called by plugins during static initialization to register themselves.
     */
    bool RegisterPlugin(const std::string &name, Plugin *instance)
    {
        if (!instance)
        {
            Log("[PLUGIN] Error: Cannot register null component manager for '%s'", name.c_str());
            return false;
        }

        registeredPlugins.push_back(instance);

        Log("[PLUGIN] Registered component manager instance: %s (%d plugins total)", name.c_str(), registeredPlugins.size());

        return true;
    }

    /**
     * Update all registered plugin component managers.
     * This is called from thermion's main render loop.
     */
    void UpdatePlugins(float deltaTime)
    {
        TRACE("Updating %d component managers", registeredPlugins.size());
        for (auto *manager : registeredPlugins)
        {
            manager->update(deltaTime);
        }
    }

    /**
     * Cleanup all plugin component managers.
     */
    void CleanupPlugins()
    {
        for (auto *manager : registeredPlugins)
        {
            manager->cleanup();
        }
        registeredPlugins.clear();
    }

} // namespace thermion
