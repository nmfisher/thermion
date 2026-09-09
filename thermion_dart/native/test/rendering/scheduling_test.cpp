#include "rendering/FrameRateGate.hpp"
#include "rendering/FrameScheduler.hpp"
#include "rendering/RenderThread.hpp"

#include <atomic>
#include <chrono>
#include <cstdlib>
#include <future>
#include <iostream>
#include <stdexcept>
#include <vector>

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

static std::vector<uint32_t> errors;
static void taskFailed(uint32_t id, const char* message) {
    require(message && std::string(message).find("expected") != std::string::npos,
            "error lost its message");
    errors.push_back(id);
    std::free(const_cast<char*>(message));
}

static void testTaskErrors() {
    RenderThread thread;
    pushTaskErrorContext(7, taskFailed);
    pushTaskErrorContext(8, taskFailed);
    thread.addDetachedTask([] { throw std::runtime_error("expected scoped failure"); });
    popTaskErrorContext();
    require(currentTaskError.requestId == 7, "nested error scope did not restore parent");
    popTaskErrorContext();
    require(!currentTaskError.callback, "error context leaked into unrelated dispatch");
    std::packaged_task<void()> barrier([] {});
    thread.addTask(barrier).get();
    require(errors == std::vector<uint32_t>({8, 7}), "task error did not settle every active scope");
}

static void testQueue() {
    std::vector<int> order;
    {
        RenderThread thread;
        for (int i = 0; i < 10000; ++i) {
            thread.addDetachedTask([&order, i] { order.push_back(i); });
        }
        thread.addDetachedTask([] { throw std::runtime_error("expected detached-task test error"); });
        thread.addDetachedTask([&order] { order.push_back(10000); });
        std::packaged_task<void()> failed([] { throw std::runtime_error("expected packaged error"); });
        auto result = thread.addTask(failed);
        try {
            result.get();
            require(false, "packaged exception was lost");
        } catch (const std::runtime_error& error) {
            require(std::string(error.what()) == "expected packaged error", "wrong packaged error");
        }
    }
    require(order.size() == 10001, "shutdown failed to drain tasks or worker died on exception");
    for (size_t i = 0; i < order.size(); ++i) require(order[i] == int(i), "FIFO order changed");
    // Exercise transitions between an idle queue and shutdown repeatedly.
    for (int i = 0; i < 1000; ++i) {
        RenderThread thread;
        std::packaged_task<void()> task([] {});
        thread.addTask(task).get();
    }
}

int main() {
    testRateGate();
    testTimer();
    testQueue();
    testTaskErrors();
    std::cout << "Scheduling tests passed\n";
}
