#pragma once

#include <vector>
#include <optional>
#include <cstdint>
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

    enum class LogicalKey : uint8_t {
        w = 0,
        a = 1,
        s = 2,
        d = 3,
        g = 4,
        r = 5,
        x = 6,
        y = 7,
        z = 8,
        shiftLeft = 9,
        shiftRight = 10,
        esc = 11,
        del = 12,
        space = 13,
        backtick = 14,
        key0 = 15,
        key1 = 16,
        key2 = 17,
        key3 = 18,
        key4 = 19,
        key5 = 20,
        key6 = 21,
        key7 = 22,
        key8 = 23,
        key9 = 24,
        period = 25,
        numpad0 = 26,
        numpad1 = 27,
        numpad2 = 28,
        numpad3 = 29,
        numpad4 = 30,
        numpad5 = 31,
        numpad6 = 32,
        numpad7 = 33,
        numpad8 = 34,
        numpad9 = 35,
        numpadPeriod = 36,
        numpadEnter = 37,
        enter = 38,
        arrow_up = 39,
        arrow_down = 40,
        arrow_left = 41,
        arrow_right = 42
    };

    // Bitmask utilities for LogicalKey
    constexpr inline uint64_t keyToBit(LogicalKey key) {
        return uint64_t(1) << static_cast<uint8_t>(key);
    }

    constexpr inline bool isKeyPressed(uint64_t bitmask, LogicalKey key) {
        return (bitmask & keyToBit(key)) != 0;
    }

    constexpr inline uint64_t setKeyPressed(uint64_t bitmask, LogicalKey key) {
        return bitmask | keyToBit(key);
    }

    constexpr inline uint64_t clearKeyPressed(uint64_t bitmask, LogicalKey key) {
        return bitmask & ~keyToBit(key);
    }

    // Bitmask utilities for MouseButton
    constexpr inline uint8_t mouseButtonToBit(MouseButton button) {
        return uint8_t(1) << static_cast<uint8_t>(button);
    }

    constexpr inline bool isMouseButtonPressed(uint8_t bitmask, MouseButton button) {
        return (bitmask & mouseButtonToBit(button)) != 0;
    }

    constexpr inline uint8_t setMouseButtonPressed(uint8_t bitmask, MouseButton button) {
        return bitmask | mouseButtonToBit(button);
    }

    constexpr inline uint8_t clearMouseButtonPressed(uint8_t bitmask, MouseButton button) {
        return bitmask & ~mouseButtonToBit(button);
    }

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
        shiftLeft,
        shiftRight,
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
        numpadEnter,
        arrow_up,
        arrow_down,
        arrow_left,
        arrow_right
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
        uint64_t getCurrentPressedKeys() const { return mCurrentPressedKeys; }
        const float2& getCurrentMousePosition() const { return mCurrentMousePosition; }
        uint8_t getCurrentPressedMouseButtons() const { return mCurrentPressedMouseButtons; }

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
        uint64_t mCurrentPressedKeys = 0;
        uint8_t mCurrentPressedMouseButtons = 0;
    };

} // namespace thermion::plugin::input