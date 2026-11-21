#pragma once

#include <algorithm>
#include <cstdint>

namespace thermion {

// Single-consumer rate gate shared by platform ticks and the web renderer.
// Deadlines retain their phase across late ticks without queuing catch-up work.
class FrameRateGate {
public:
    // nanos is a nondecreasing timestamp in nanoseconds from one clock domain.
    // The first tick (including zero) and the first tick at a different positive
    // fps are admitted immediately and establish a new deadline phase. fps <= 0
    // admits every tick and clears that phase. Call reset() before changing clocks.
    // Ticks up to 1 ms early are admitted to tolerate source timestamp jitter;
    // this is an average cadence target, not a minimum gap between callbacks.
    bool admit(uint64_t nanos, int fps) {
        if (fps <= 0) {
            reset();
            return true;
        }
        const uint64_t interval = std::max<uint64_t>(1, 1000000000ULL / fps);
        if (_fps != fps || !_initialized) {
            _fps = fps;
            _next = nanos;
            _initialized = true;
        }
        constexpr uint64_t tolerance = 1000000ULL;
        if (_next > nanos && _next - nanos > tolerance) return false;
        if (_next <= nanos) {
            _next += ((nanos - _next) / interval + 1) * interval;
        } else {
            _next += interval;
        }
        return true;
    }

    void reset() {
        _fps = 0;
        _next = 0;
        _initialized = false;
    }

private:
    int _fps = 0;
    uint64_t _next = 0;
    bool _initialized = false;
};

} // namespace thermion
