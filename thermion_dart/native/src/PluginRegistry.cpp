#include "PluginAPI.hpp"
#include "IPluginComponentManager.hpp"
#include <vector>
#include <memory>
#include <map>
#include <functional>
#include <string>
#include <emscripten/console.h>

namespace thermion {

namespace {
    // Global registry of plugin component managers (instances ready for use)
    std::vector<IPluginComponentManager*> g_pluginComponentManagers;

    // Dynamic registration map: name -> instance pointer
    std::map<std::string, IPluginComponentManager*> g_registeredComponentManagers;

    bool g_initialized = false;
}

/**
 * Register a component manager instance directly.
 * This is called by plugins during static initialization to register themselves.
 */
bool RegisterComponentManager(const std::string& name, IPluginComponentManager* instance) {
    if (!instance) {
        emscripten_console_logf("[PLUGIN] Error: Cannot register null component manager for '%s'", name.c_str());
        return false;
    }

    if (g_registeredComponentManagers.find(name) != g_registeredComponentManagers.end()) {
        emscripten_console_logf("[PLUGIN] Warning: Component manager '%s' already registered, ignoring duplicate", name.c_str());
        return false;
    }

    g_registeredComponentManagers[name] = instance;
    emscripten_console_logf("[PLUGIN] Registered component manager instance: %s", name.c_str());
    return true;
}

/**
 * Initialize and register all available plugin component managers.
 * This function is called automatically during system startup.
 */
void RegisterPluginComponentManagers() {
    if (g_initialized) {
        emscripten_console_logf("[PLUGIN] Component managers already registered, skipping");
        return;
    }

    emscripten_console_logf("[PLUGIN] Activating %d registered component managers...",
                           (int)g_registeredComponentManagers.size());

    // Move all registered instances to active registry
    for (const auto& pair : g_registeredComponentManagers) {
        const std::string& name = pair.first;
        IPluginComponentManager* manager = pair.second;

        if (manager) {
            emscripten_console_logf("[PLUGIN] Activating component manager: %s", name.c_str());
            g_pluginComponentManagers.push_back(manager);
        } else {
            emscripten_console_logf("[PLUGIN] Warning: Null component manager for '%s'", name.c_str());
        }
    }

    emscripten_console_logf("[PLUGIN] Successfully activated %d plugin component managers",
                           (int)g_pluginComponentManagers.size());

    g_initialized = true;
}

/**
 * Update all registered plugin component managers.
 * This is called from thermion's main render loop.
 */
void UpdatePluginComponentManagers(float deltaTime) {
    for (auto* manager : g_pluginComponentManagers) {
        manager->update(deltaTime);
    }
}

/**
 * Cleanup all plugin component managers.
 */
void CleanupPluginComponentManagers() {
    for (auto* manager : g_pluginComponentManagers) {
        manager->cleanup();
    }
    g_pluginComponentManagers.clear();
    // Note: We don't delete the instances since plugins own their lifecycle
    g_initialized = false;
}

} // namespace thermion

