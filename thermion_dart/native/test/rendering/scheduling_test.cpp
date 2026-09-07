#include "rendering/FrameRateGate.hpp"
#include "rendering/FrameScheduler.hpp"

#include <atomic>
#include <chrono>
#include <iostream>
#include <stdexcept>

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
}

static void testTimer() {
    TimerFrameScheduler timer(1);
    std::atomic<int> count{0};
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
    timer.setTargetFps(1);
    auto stoppedAt = std::chrono::steady_clock::now();
    timer.stop();
    require(std::chrono::steady_clock::now() - stoppedAt < 500ms, "timer stop waited for deadline");
}

int main() {
    testRateGate();
    testTimer();
    std::cout << "Scheduling tests passed\n";
}
