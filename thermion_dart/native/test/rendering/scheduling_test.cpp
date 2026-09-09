#include "rendering/FrameRateGate.hpp"
#include "rendering/FrameScheduler.hpp"
#include "rendering/UploadCompletion.hpp"

#include <atomic>
#include <chrono>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <utility>

using namespace thermion;
using namespace std::chrono_literals;

static void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

static void testRateGate() {
    for (auto rates : {std::pair{60, 30}, {90, 60}, {120, 60}, {144, 60}}) {
        FrameRateGate gate;
        int admitted = 0;
        for (int i = 0; i < rates.first * 10; ++i) {
            admitted += gate.admit(1000000000ULL + uint64_t(i) * 1000000000ULL / rates.first,
                                   rates.second);
        }
        require(admitted == rates.second * 10, "rate gate lost requested average cadence");
    }
    FrameRateGate gate;
    require(gate.admit(0, 30), "initial zero timestamp rejected");
    require(!gate.admit(1000, 30), "zero timestamp must not reset gate on next tick");
    require(gate.admit(10000000000ULL, 30), "stalled source did not resume");
    require(!gate.admit(10000000001ULL, 30), "stalled source burst to catch up");
    require(gate.admit(10000000001ULL, 120), "new rate did not apply immediately");
    require(gate.admit(10000000002ULL, 0), "unlimited gate rejected tick");
    gate.reset();
    require(gate.admit(1, 30), "reset retained old deadline");

    gate.reset();
    require(gate.admit(0, 30), "first tick rejected");
    require(!gate.admit(32333332, 30), "admitted more than 1 ms early");
    require(gate.admit(32333333, 30), "rejected tick at tolerance boundary");
    require(!gate.admit(33333333, 30), "early admission did not advance deadline");

    // Assert spacing as well as totals: 60 fps on 90 Hz alternates 2/1 vsyncs.
    gate.reset();
    for (int i = 0; i < 90; ++i) {
        require(gate.admit(uint64_t(i) * 1000000000ULL / 90, 60) == (i % 3 != 1),
                "non-divisor cadence has the wrong spacing");
    }
}

static void testFrameTime() {
    FrameTimeMapper mapper;
    // Different epochs; a 0.2 ms old frame should retain its age approximately.
    require(mapper.map(9800000, 10000000, 5000000000) == 4999800000,
            "clock conversion lost frame age");
    require(mapper.map(std::nullopt, 11000000, 5001000000) == 5001000000,
            "missing frame did not use delivery time");
    require(mapper.map(13000000, 12000000, 5002000000) == 5002000000,
            "future frame escaped delivery-time fallback");
    // Recovery can produce an older estimate than the previous delivery-time
    // fallback. Neither rate admission nor animation time may move backwards.
    require(mapper.map(11500000, 12500000, 5002500000) == 5002000000,
            "recovery moved frame time backwards");
    mapper.reset();
    require(mapper.map(0, 20, 10) == 10, "frame age underflowed steady time");
    mapper.reset();
    require(mapper.map(0, 0, 0) == 0, "zero epoch mishandled");
    // A fresh offset after system sleep must be used, not a startup calibration.
    require(mapper.map(9800000, 10000000, 9000000000) == 8999800000,
            "conversion retained a stale clock offset");
}

#if __APPLE__ && TARGET_OS_OSX
static void testDisplayLinkTime() {
    const mach_timebase_info_data_t timebase{1, 1};
    CVTimeStamp output{};
    output.flags = kCVTimeStampHostTimeValid | kCVTimeStampVideoRefreshPeriodValid;
    output.hostTime = 10000000000ULL;
    output.videoRefreshPeriod = 1;
    output.videoTimeScale = 50;
    require(precedingVsyncNanos(output, timebase) == 9980000000ULL,
            "predicted presentation was not shifted to preceding vsync");
    output.flags |= kCVTimeStampRateScalarValid;
    output.rateScalar = 2;
    require(precedingVsyncNanos(output, timebase) == 9990000000ULL,
            "measured refresh rate was ignored");
    const auto valid = output;
    for (uint64_t flag : {uint64_t(kCVTimeStampHostTimeValid),
                          uint64_t(kCVTimeStampVideoRefreshPeriodValid)}) {
        output = valid;
        output.flags &= ~flag;
        FrameTimeMapper mapper;
        require(mapper.map(precedingVsyncNanos(output, timebase), 9990000000ULL,
                           20000000000ULL) == 20000000000ULL,
                "missing display metadata did not fall back to delivery time");
    }
    for (double rate : {0.0, -1.0, std::numeric_limits<double>::infinity(),
                        std::numeric_limits<double>::quiet_NaN()}) {
        output = valid;
        output.rateScalar = rate;
        require(!precedingVsyncNanos(output, timebase), "invalid rate scalar accepted");
    }
    output = valid;
    output.videoTimeScale = 0;
    require(!precedingVsyncNanos(output, timebase), "zero video scale accepted");
    output = valid;
    output.videoRefreshPeriod = -1;
    require(!precedingVsyncNanos(output, timebase), "negative refresh period accepted");
    output = valid;
    output.hostTime = 1;
    require(!precedingVsyncNanos(output, timebase), "preceding vsync underflowed");
    FrameTimeMapper mapper;
    require(mapper.map(precedingVsyncNanos(valid, timebase), 9000000000ULL,
                       20000000000ULL) == 20000000000ULL,
            "future preceding-vsync estimate escaped fallback");
    // The product overflows uint64_t, although the final nanoseconds fit.
    require(machTimeNanos(300000000000000000ULL, {125, 3}) ==
            12500000000000000000ULL, "Mach conversion overflowed");
}
#endif

static void testTimer(FrameScheduler& timer) {
    std::atomic<int> count{0};
    // Stop before count is destroyed, including when an assertion throws.
    struct StopOnExit {
        FrameScheduler& timer;
        ~StopOnExit() { timer.stop(); }
    } stopOnExit{timer};
    timer.setTargetFps(1);
    timer.start([](uint64_t, void* context) {
        static_cast<std::atomic<int>*>(context)->fetch_add(1);
    }, &count);
    const auto initialDeadline = std::chrono::steady_clock::now() + 1s;
    while (count.load() == 0 && std::chrono::steady_clock::now() < initialDeadline) {
        std::this_thread::sleep_for(1ms);
    }
    require(count.load() > 0, "timer never started");
    timer.setTargetFps(120);
    const auto deadline = std::chrono::steady_clock::now() + 500ms;
    while (count.load() < 5 && std::chrono::steady_clock::now() < deadline) {
        std::this_thread::sleep_for(1ms);
    }
    require(count.load() >= 5, "rate change did not interrupt slow timer");
    const int beforeSlow = count.load();
    timer.setTargetFps(1);
    const auto slowDeadline = std::chrono::steady_clock::now() + 500ms;
    while (count.load() <= beforeSlow && std::chrono::steady_clock::now() < slowDeadline) {
        std::this_thread::sleep_for(1ms);
    }
    require(count.load() > beforeSlow, "rate decrease did not apply immediately");
    std::this_thread::sleep_for(30ms); // let the source enter its one-second wait
    auto stoppedAt = std::chrono::steady_clock::now();
    timer.stop();
    require(std::chrono::steady_clock::now() - stoppedAt < 500ms, "timer stop waited for deadline");
}

#ifdef _WIN32
class FailedVBlankScheduler : public DXGIFrameScheduler {
public:
    FailedVBlankScheduler() : DXGIFrameScheduler(1) {}
    ~FailedVBlankScheduler() override { stop(); }
    int waitCalls = 0; // read only after stop() joins the source thread
protected:
    bool waitForVBlank(IDXGIOutput*) override {
        ++waitCalls;
        return false;
    }
};
#endif

static int uploadCompletions = 0;
static void uploadReleased(int32_t id) {
    require(id == 42, "upload lost its callback ID");
    ++uploadCompletions;
}

static void testUploadCompletion() {
    uploadCompletions = 0;
    auto* empty = new UploadCompletion(uploadReleased, 42);
    empty->release(); // Validation failed before any buffer was submitted.
    require(uploadCompletions == 1, "empty submission did not release");

    auto* partial = new UploadCompletion(uploadReleased, 42);
    partial->addBuffer();
    partial->release(); // A later mip failed; submission has ended.
    require(uploadCompletions == 1, "partial upload signalled before buffer release");
    partial->release(); // The only submitted buffer is now done.
    require(uploadCompletions == 2, "partial upload did not signal exactly once");

    auto* early = new UploadCompletion(uploadReleased, 42);
    early->addBuffer();
    early->release(); // First buffer completes while submission is still active.
    require(uploadCompletions == 2, "early buffer ended an active submission");
    early->addBuffer();
    early->release(); // Submission ends.
    require(uploadCompletions == 2, "later buffer was not counted");
    early->release();
    require(uploadCompletions == 3, "successful upload did not signal exactly once");
}

int main() {
    testUploadCompletion();
    testRateGate();
    testFrameTime();
#if __APPLE__ && TARGET_OS_OSX
    testDisplayLinkTime();
#endif
    TimerFrameScheduler timer(1);
    testTimer(timer);
#ifdef _WIN32
    FailedVBlankScheduler fallback;
    testTimer(fallback);
    require(fallback.waitCalls == 1, "failed VBlank was retried instead of using timer");
#endif
    std::cout << "Scheduling tests passed\n";
}
