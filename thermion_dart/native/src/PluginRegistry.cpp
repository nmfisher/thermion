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
        std::vector<std::string> registeredPluginNames;
    }

    /**
     * Register a component manager instance directly.
     * This is called by plugins during static initialization to register themselves.
     */
    bool RegisterPlugin(const std::string &name, Plugin *instance)
    {
        if (!instance)
        {
            Log("[PLUGIN] Error: Cannot register null plugin '%s'", name.c_str());
            return false;
        }

        for(int i = 0; i < registeredPluginNames.size(); i++) {

            if(registeredPluginNames[i] == name) {
                registeredPluginNames.erase(registeredPluginNames.begin() + i);
                registeredPlugins.erase(registeredPlugins.begin() + i);
                Log("[PLUGIN] Erased existing plugin under name %s (%lu plugins remaining)", name.c_str(), registeredPlugins.size());    
                break;
            }
        }    

        registeredPlugins.push_back(instance);
        registeredPluginNames.push_back(name);

        Log("[PLUGIN] Registered plugin: %s (%lu plugins total)", name.c_str(), registeredPlugins.size());

        return true;
    }

    /**
     * Update all registered plugin component managers.
     * This is called from thermion's main render loop.
     */
    void UpdatePlugins(uint64_t frameTimeInNanos)
    {
        for (auto *manager : registeredPlugins)
        {
            manager->update(frameTimeInNanos);
        }
        TRACE("[PLUGIN] Updated %d plugins", registeredPlugins.size());
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
        TRACE("All plugins removed");
    }

} // namespace thermion
