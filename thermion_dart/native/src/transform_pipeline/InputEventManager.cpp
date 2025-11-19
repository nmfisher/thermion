#include "transform_pipeline/InputEventManager.hpp"
#include "Log.hpp"

namespace thermion::plugin::input {

    void InputEventManager::handleMouseEvent(const MouseEvent& event)
    {
        // Queue events globally - will be processed during update()
        mGlobalMouseEvents.push_back(event);
        TRACE("[InputEventManager] Queued global mouse event (total: %zu)", mGlobalMouseEvents.size());
    }

    void InputEventManager::handleKeyEvent(const KeyEvent& event)
    {
        // Queue events globally - will be processed during update()
        mGlobalKeyEvents.push_back(event);

        // Enhanced debugging for key events
        switch (event.type)
        {
            case KeyEventType::down:
                TRACE("[InputEventManager] KEY DOWN: Queued global key %d press (total queued: %zu)",
                      static_cast<int>(event.logicalKey), mGlobalKeyEvents.size());
                break;
            case KeyEventType::up:
                TRACE("[InputEventManager] KEY UP: Queued global key %d release (total queued: %zu)",
                      static_cast<int>(event.logicalKey), mGlobalKeyEvents.size());
                break;
        }
    }

    void InputEventManager::handleScrollEvent(const ScrollEvent& event)
    {
        // Queue events globally - will be processed during update()
        mGlobalScrollEvents.push_back(event);
        TRACE("[InputEventManager] Queued global scroll event (total: %zu)", mGlobalScrollEvents.size());
    }

    void InputEventManager::update()
    {
        TRACE("[InputEventManager] Processing global input events");

        // Count pressed keys for logging
        uint32_t numPressedKeys = __builtin_popcountll(mCurrentPressedKeys);

        // Log global events at start of update
        TRACE("[InputEventManager] Global events: %zu mouse, %zu key, %zu scroll queued (current pressedKeys: %u, bitmask: 0x%016llx)",
              mGlobalMouseEvents.size(), mGlobalKeyEvents.size(), mGlobalScrollEvents.size(), numPressedKeys,
              static_cast<unsigned long long>(mCurrentPressedKeys));

        // Process global mouse events
        for (const auto& event : mGlobalMouseEvents)
        {
            TRACE("[InputEventManager] Processing global mouse event type %d: delta(%.2f, %.2f)",
                  static_cast<int>(event.type), event.delta.x, event.delta.y);

            // Update global mouse state
            mCurrentMousePosition = event.localPosition;
            mCurrentMouseDelta += event.delta;

            TRACE("[InputEventManager] Global mouse delta accumulated: (%.2f, %.2f)",
                  mCurrentMouseDelta.x, mCurrentMouseDelta.y);

            // Handle button events
            if (event.type == MouseEventType::buttonDown && event.button.has_value())
            {
                switch (event.button.value())
                {
                    case MouseButton::left:
                        TRACE("[InputEventManager] Left mouse button pressed globally");
                        break;
                    case MouseButton::right:
                        TRACE("[InputEventManager] Right mouse button pressed globally");
                        break;
                    case MouseButton::middle:
                        TRACE("[InputEventManager] Middle mouse button pressed globally");
                        break;
                }
            }
        }

        // Process global keyboard events
        TRACE("[InputEventManager] Processing %zu global key events (current pressedKeys: %u)",
              mGlobalKeyEvents.size(), numPressedKeys);

        for (const auto& event : mGlobalKeyEvents)
        {
            switch (event.type)
            {
                case KeyEventType::down:
                    {
                        bool wasAlreadyPressed = isKeyPressed(mCurrentPressedKeys, event.logicalKey);
                        mCurrentPressedKeys = setKeyPressed(mCurrentPressedKeys, event.logicalKey);
                        uint32_t newNumPressed = __builtin_popcountll(mCurrentPressedKeys);
                        TRACE("[InputEventManager] KEY DOWN PROCESSED: Key %d pressed globally (wasAlreadyPressed: %s, total pressedKeys now: %u)",
                              static_cast<int>(event.logicalKey), wasAlreadyPressed ? "true" : "false", newNumPressed);
                        break;
                    }
                case KeyEventType::up:
                    {
                        bool wasPressed = isKeyPressed(mCurrentPressedKeys, event.logicalKey);
                        mCurrentPressedKeys = clearKeyPressed(mCurrentPressedKeys, event.logicalKey);
                        uint32_t newNumPressed = __builtin_popcountll(mCurrentPressedKeys);
                        TRACE("[InputEventManager] KEY UP PROCESSED: Key %d released globally (wasPressed: %s, total pressedKeys now: %u)",
                              static_cast<int>(event.logicalKey), wasPressed ? "true" : "false", newNumPressed);
                        break;
                    }
            }
        }

        // WARNING: Large event queue detected
        if (mGlobalKeyEvents.size() > 10) {
            TRACE("[InputEventManager] WARNING: %zu pending key events - possible overflow!",
                  mGlobalKeyEvents.size());
        }

        // Clear global event queues after processing
        TRACE("[InputEventManager] Clearing global event queues (before clear: %zu mouse, %zu key, %zu scroll)",
              mGlobalMouseEvents.size(), mGlobalKeyEvents.size(), mGlobalScrollEvents.size());

        mGlobalMouseEvents.clear();
        mGlobalKeyEvents.clear();
        mGlobalScrollEvents.clear();

        TRACE("[InputEventManager] Global event queues cleared");
        numPressedKeys = __builtin_popcountll(mCurrentPressedKeys);
        TRACE("[InputEventManager] Current state: mouseDelta(%.2f, %.2f), pressedKeys: %u (bitmask: 0x%016llx)",
              mCurrentMouseDelta.x, mCurrentMouseDelta.y, numPressedKeys, static_cast<unsigned long long>(mCurrentPressedKeys));
    }

    void InputEventManager::cleanup()
    {
        TRACE("[InputEventManager] Cleanup");

        // Clear global event queues
        mGlobalMouseEvents.clear();
        mGlobalKeyEvents.clear();
        mGlobalScrollEvents.clear();

        // Clear global input state
        mCurrentMousePosition = {0, 0};
        mCurrentMouseDelta = {0, 0};
        mCurrentPressedKeys = 0;

        TRACE("[InputEventManager] Cleanup completed - cleared global input state");
    }

    void InputEventManager::resetMouseDelta()
    {
        TRACE("[InputEventManager] Resetting mouse delta from (%.2f, %.2f) to (0, 0)",
              mCurrentMouseDelta.x, mCurrentMouseDelta.y);
        mCurrentMouseDelta = {0, 0};
    }

} // namespace thermion::plugin::input