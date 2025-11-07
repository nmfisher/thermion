#pragma once

#include <utils/Entity.h>
#include <memory>
#include <functional>
#include <string>

namespace thermion::plugin {
    /**
     * Abstract base interface for plugins.
     * Plugins should inherit from this interface to integrate with
     * the main animation update loop.
     */
    class Plugin {
    public:
        virtual ~Plugin() = default;

        /**
         * Called once per frame from the main animation update loop.
         * @param frameTimeInNanos Start time (in nanoseconds) of current frame
         */
        virtual void update(uint64_t frameTimeInNanos) = 0;

        /**
         * Returns a unique name for this component manager.
         * Used for debugging and logging purposes.
         */
        virtual const char* getName() const = 0;

        /**
         * Optional cleanup method called when the manager is being destroyed.
         * Override if you need custom cleanup logic.
         */
        virtual void cleanup() {}
    };

    /**
     * Register a component manager instance directly.
     * This function should be called during static initialization to register
     * a component manager with the plugin system.
     *
     * @param name Unique name for the component manager
     * @param instance Pointer to the component manager instance
     * @return true if registration succeeded, false if name already exists or instance is null
     */
    bool RegisterPlugin(const std::string& name, Plugin* instance);
}

