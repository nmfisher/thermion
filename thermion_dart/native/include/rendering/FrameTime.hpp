#pragma once

#include <algorithm>
#include <cstdint>
#include <optional>

#if __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#include <CoreVideo/CoreVideo.h>
#include <mach/mach_time.h>
#include <cmath>
#endif
#endif

namespace thermion {

// Maps a platform frame time using a pair of nearby clock samples. Frame age
// is approximate: preemption between the samples adds conversion error. An
// unavailable, future, or unrepresentable frame time falls back to delivery
// time, like TimerFrameScheduler. Keep output nondecreasing when recovering
// from missing timing data or when the sampled clock offset changes.
// Owned by one source callback context; reset only after that context stops.
class FrameTimeMapper {
public:
    uint64_t map(std::optional<uint64_t> sourceFrame, uint64_t sourceNow,
                 uint64_t steadyNow) {
        uint64_t mapped = steadyNow;
        if (sourceFrame && *sourceFrame <= sourceNow) {
            const uint64_t age = sourceNow - *sourceFrame;
            if (age <= steadyNow) mapped -= age;
        }
        _last = std::max(_last, mapped);
        return _last;
    }

    void reset() { _last = 0; }

private:
    uint64_t _last = 0;
};

#if __APPLE__ && TARGET_OS_OSX
// The timebase comes from mach_timebase_info (nonzero denominator). Widen
// before multiplying so the intermediate cannot overflow at long uptimes.
inline uint64_t machTimeNanos(uint64_t ticks, mach_timebase_info_data_t timebase) {
    return static_cast<unsigned __int128>(ticks) * timebase.numer / timebase.denom;
}

// CVDisplayLink supplies a predicted presentation time. Estimate the preceding
// vsync from the nominal period, adjusted by the measured rate when available.
// https://developer.apple.com/documentation/corevideo/cvtimestamp/ratescalar
// Missing/invalid fields return no estimate; the mapper then uses delivery time.
inline std::optional<uint64_t> precedingVsyncNanos(
        const CVTimeStamp& output, mach_timebase_info_data_t timebase) {
    constexpr uint64_t required = kCVTimeStampHostTimeValid |
        kCVTimeStampVideoRefreshPeriodValid;
    if ((output.flags & required) != required || output.videoTimeScale <= 0 ||
        output.videoRefreshPeriod <= 0) return std::nullopt;

    long double rate = 1;
    if (output.flags & kCVTimeStampRateScalarValid) {
        if (!std::isfinite(output.rateScalar) || output.rateScalar <= 0)
            return std::nullopt;
        rate = output.rateScalar;
    }
    const uint64_t presentation = machTimeNanos(output.hostTime, timebase);
    const long double period = static_cast<long double>(output.videoRefreshPeriod) *
        1000000000.0L / output.videoTimeScale / rate;
    if (!std::isfinite(period) || period < 1 || period >= presentation)
        return std::nullopt;
    return presentation - static_cast<uint64_t>(period);
}
#endif

} // namespace thermion
