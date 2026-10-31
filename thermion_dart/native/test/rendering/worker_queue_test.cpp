#include "rendering/JobThread.hpp"
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <type_traits>

using namespace thermion;
using namespace std::chrono_literals;

// Base pointers borrow workers. Destruction uses the concrete owner's API.
static_assert(!std::is_destructible_v<JobThreadBase>);

static void check(bool condition) {
    if (!condition) std::abort();
}

int main() {
    for (int round = 0; round < 25; ++round) {
        int executed = 0;
        const auto caller = std::this_thread::get_id();
        {
            auto owner = JobThread::create();
            JobThreadBase& worker = *owner;
            check(!worker.isStopping());
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
            std::promise<void> draining;
            auto started = draining.get_future();
            worker.addDetachedTask([&] {
                draining.set_value();
                const auto deadline = std::chrono::steady_clock::now() + 2s;
                while (!worker.isStopping()) {
                    check(std::chrono::steady_clock::now() < deadline);
                    std::this_thread::yield();
                }
                // Accepted work can submit its completion during destruction.
                worker.addDetachedTask([&] { check(executed++ == 200); });
            });
            check(started.wait_for(2s) == std::future_status::ready);
            // Both implementations consume ownership through the same API.
            JobThread::destroy(std::move(owner));
            check(!owner);
            check(executed == 201);
        }
        check(executed == 201);
    }
    std::puts("PASS: native FIFO, packaged result, nested completion and 25 shutdown cycles");
}
