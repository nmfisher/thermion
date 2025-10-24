#pragma once

#include <utils/Entity.h>
#include <memory>
#include <functional>
#include <string>

namespace thermion::plugin {
    /**
     * Abstract base interface for plugin component managers.
     * Plugin component managers should inherit from this interface alongside
     * utils::SingleInstanceComponentManager<ComponentType> to integrate with
     * the main animation update loop.
     */
    class Plugin {
    public:
        virtual ~Plugin() = default;

        /**
         * Called once per frame from the main animation update loop.
         * @param deltaTime Time elapsed since last frame in seconds
         */
        virtual void update(float deltaTime) = 0;

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

/**
 * Convenience macro for auto-registering component managers.
 * Place this at the end of your component manager implementation file.
 *
 * Usage:
 * REGISTER_COMPONENT_MANAGER(CollisionComponentManager)
 *
 * This will automatically create an instance and register it when the plugin is loaded.
 */
#define REGISTER_COMPONENT_MANAGER(ClassName) \
    namespace { \
        static std::unique_ptr<thermion::ClassName> g_##ClassName##_instance = \
            std::make_unique<thermion::ClassName>(); \
        static bool g_##ClassName##_registered = thermion::RegisterPlugin( \
            #ClassName, \
            g_##ClassName##_instance.get() \
        ); \
    }