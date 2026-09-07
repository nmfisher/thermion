#pragma once

#include <algorithm>
#include <cstdint>

namespace thermion {

// Single-consumer rate gate shared by platform ticks and the web renderer.
// Deadlines retain their phase across late ticks without queuing catch-up work.
class FrameRateGate {
public:
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
