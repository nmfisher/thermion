#pragma once

#include <vector>
#include <unordered_map>
#include "InputEventManager.hpp"

namespace thermion::plugin::input {

    /**
     * Enumeration of all possible intent actions.
     * Standard movement intents are handled specially for performance,
     * while custom intents can be added without modifying the calculator.
     */
    enum class IntentAction {
        // Standard movement intents (handled specially)
        MoveForward,
        MoveBackward,
        MoveLeft,
        MoveRight,
        Jump,
        Sprint,

        // Extensible custom intents
        Custom1,
        Custom2,
        Custom3,
        Custom4,
        Custom5,
        Custom6,
        Custom7,
        Custom8,
        Custom9,
        Custom10,

        // Additional common game intents
        Crouch,
        Interact,
        UseItem,
        Reload,
        AltFire,

        // Add more as needed...
    };

    /**
     * Maps a logical key to an intent action with optional value multiplier.
     */
    struct KeyBinding {
        LogicalKey key;
        IntentAction action;
        float value = 1.0f;  // Allows for variable strength bindings

        KeyBinding() = default;
        KeyBinding(LogicalKey k, IntentAction a, float v = 1.0f)
            : key(k), action(a), value(v) {}
    };

    /**
     * Configuration for input processing.
     * This can be modified at runtime to change keybindings and behavior.
     */
    struct InputConfiguration {
        std::vector<KeyBinding> keyBindings;
        float mouseSensitivity = 1.0f;
        bool invertMouseY = false;

        InputConfiguration() = default;

        /**
         * Add a keybinding to the configuration.
         */
        void addBinding(LogicalKey key, IntentAction action, float value = 1.0f) {
            keyBindings.emplace_back(key, action, value);
        }

        /**
         * Remove all bindings for a specific key.
         */
        void removeBindingsForKey(LogicalKey key) {
            keyBindings.erase(
                std::remove_if(keyBindings.begin(), keyBindings.end(),
                    [key](const KeyBinding& binding) { return binding.key == key; }),
                keyBindings.end()
            );
        }

        /**
         * Remove all bindings for a specific action.
         */
        void removeBindingsForAction(IntentAction action) {
            keyBindings.erase(
                std::remove_if(keyBindings.begin(), keyBindings.end(),
                    [action](const KeyBinding& binding) { return binding.action == action; }),
                keyBindings.end()
            );
        }

        /**
         * Clear all keybindings.
         */
        void clearBindings() {
            keyBindings.clear();
        }
    };

    /**
     * Factory function to create default WASD configuration.
     * This provides backwards compatibility with the original hardcoded behavior.
     */
    inline InputConfiguration createDefaultConfiguration() {
        InputConfiguration config;

        // WASD movement
        config.addBinding(LogicalKey::w, IntentAction::MoveForward);
        config.addBinding(LogicalKey::s, IntentAction::MoveBackward);
        config.addBinding(LogicalKey::a, IntentAction::MoveLeft);
        config.addBinding(LogicalKey::d, IntentAction::MoveRight);

        // Jump and sprint
        config.addBinding(LogicalKey::space, IntentAction::Jump);
        config.addBinding(LogicalKey::shiftLeft, IntentAction::Sprint);
        config.addBinding(LogicalKey::shiftRight, IntentAction::Sprint);

        config.mouseSensitivity = 1.0f;
        config.invertMouseY = false;

        return config;
    }

    /**
     * Factory function to create arrow keys configuration.
     */
    inline InputConfiguration createArrowKeysConfiguration() {
        InputConfiguration config;

        // Arrow keys movement
        config.addBinding(LogicalKey::arrow_up, IntentAction::MoveForward);
        config.addBinding(LogicalKey::arrow_down, IntentAction::MoveBackward);
        config.addBinding(LogicalKey::arrow_left, IntentAction::MoveLeft);
        config.addBinding(LogicalKey::arrow_right, IntentAction::MoveRight);

        // Jump and sprint
        config.addBinding(LogicalKey::space, IntentAction::Jump);
        config.addBinding(LogicalKey::shiftLeft, IntentAction::Sprint);
        config.addBinding(LogicalKey::shiftRight, IntentAction::Sprint);

        config.mouseSensitivity = 1.0f;
        config.invertMouseY = false;

        return config;
    }

} // namespace thermion::plugin::input
