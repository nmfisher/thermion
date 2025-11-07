#pragma once

#include <vector>
#include <unordered_set>
#include <optional>
#include <math/vec2.h>

namespace thermion::plugin::input {

    using namespace filament::math;

    // Input event enums matching Dart implementation
    enum class MouseButton {
        left,
        middle,
        right
    };

    enum class MouseEventType {
        hover,
        move,
        buttonDown,
        buttonUp
    };

    enum class KeyEventType {
        down,
        up
    };

    enum class LogicalKey {
        w,
        a,
        s,
        d,
        g,
        r,
        x,
        y,
        z,
        shift,
        esc,
        del,
        space,
        backtick,
        key0,
        key1,
        key2,
        key3,
        key4,
        key5,
        key6,
        key7,
        key8,
        key9,
        period,
        numpad0,
        numpad1,
        numpad2,
        numpad3,
        numpad4,
        numpad5,
        numpad6,
        numpad7,
        numpad8,
        numpad9,
        numpadPeriod,
        numpadEnter,
        enter
    };

    enum class PhysicalKey {
        w,
        a,
        s,
        d,
        g,
        r,
        x,
        y,
        z,
        shift,
        esc,
        del,
        space,
        backtick,
        key0,
        key1,
        key2,
        key3,
        key4,
        key5,
        key6,
        key7,
        key8,
        key9,
        enter,
        period,
        numpad0,
        numpad1,
        numpad2,
        numpad3,
        numpad4,
        numpad5,
        numpad6,
        numpad7,
        numpad8,
        numpad9,
        numpadPeriod,
        numpadEnter
    };

    // Input event structures
    struct MouseEvent {
        MouseEventType type;
        std::optional<MouseButton> button;
        float2 localPosition;
        float2 delta;
    };

    struct KeyEvent {
        KeyEventType type;
        LogicalKey logicalKey;
        PhysicalKey physicalKey;
        bool synthesized = false;
    };

    struct ScrollEvent {
        float2 localPosition;
        double delta;
    };

    /**
     * Event manager that handles input event collection and state management.
     * This class is responsible only for collecting input events and maintaining
     * global input state. It does not handle component management or movement logic.
     */
    class InputEventManager {
    public:
        InputEventManager() = default;
        ~InputEventManager() = default;

        // Event handling methods - queue events for processing
        void handleMouseEvent(const MouseEvent& event);
        void handleKeyEvent(const KeyEvent& event);
        void handleScrollEvent(const ScrollEvent& event);

        // Update method - process queued events and update global state
        void update();

        // Cleanup method - clear all event queues and state
        void cleanup();

        // Accessors for current input state
        const float2& getCurrentMouseDelta() const { return mCurrentMouseDelta; }
        const std::unordered_set<LogicalKey>& getCurrentPressedKeys() const { return mCurrentPressedKeys; }
        const float2& getCurrentMousePosition() const { return mCurrentMousePosition; }

        // Reset methods for input state
        void resetMouseDelta();

    private:
        // Global event queues - events are queued here and processed during update()
        std::vector<MouseEvent> mGlobalMouseEvents;
        std::vector<KeyEvent> mGlobalKeyEvents;
        std::vector<ScrollEvent> mGlobalScrollEvents;

        // Global input state - shared by all entities that need input
        float2 mCurrentMousePosition = {0, 0};
        float2 mCurrentMouseDelta = {0, 0};
        std::unordered_set<LogicalKey> mCurrentPressedKeys;
    };

} // namespace thermion::plugin::input