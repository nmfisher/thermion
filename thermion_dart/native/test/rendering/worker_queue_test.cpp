#include "rendering/RenderThread.hpp"
#include <chrono>
#include <cstdio>
#include <cstdlib>

using namespace thermion;
using namespace std::chrono_literals;

static void check(bool condition) {
    if (!condition) std::abort();
}

int main() {
    for (int round = 0; round < 25; ++round) {
        int executed = 0;
        const auto caller = std::this_thread::get_id();
        {
            RenderThread worker;
            std::packaged_task<int()> query([caller] {
                check(std::this_thread::get_id() != caller);
                return 42;
            });
            auto result = worker.addTask(query);
            check(result.wait_for(2s) == std::future_status::ready);
            check(result.get() == 42);
            for (int i = 0; i < 200; ++i) {
                worker.addDetachedTask([&, i] {
                    check(std::this_thread::get_id() != caller);
                    check(executed++ == i);
                });
            }
            worker.addDetachedTask([&] {
                worker.addDetachedTask([&] { check(executed++ == 200); });
            });
            // Destruction must drain on the worker and join before returning.
        }
        check(executed == 201);
    }
    std::puts("PASS: native FIFO, packaged result, nested completion and 25 shutdown cycles");
}
