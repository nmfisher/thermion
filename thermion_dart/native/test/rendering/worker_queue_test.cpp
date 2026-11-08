#include "rendering/JobThread.hpp"
#include "rendering/EngineApiLock.hpp"
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <type_traits>
#if defined(__cpp_exceptions) || defined(_CPPUNWIND)
#include <stdexcept>
#endif

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
    // Dart completions raised inside a task must run after the task, with the
    // engine API lock released (a Dart callback can block until another thread
    // that needs the lock makes progress).
    {
        auto owner = JobThread::create();
        std::atomic<bool> ran{false};
        std::atomic<bool> lockFree{false};
        std::atomic<bool> deferred{false};
        bool inTask = false;
        owner->addDetachedTask([&] {
            inTask = true;
            deferDartCallback([&] {
                deferred = !inTask;
                std::thread probe([&] {
                    if (engineApiMutex().try_lock()) {
                        lockFree = true;
                        engineApiMutex().unlock();
                    }
                });
                probe.join();
                ran = true;
            });
            inTask = false;
        });
        const auto deadline = std::chrono::steady_clock::now() + 2s;
        while (!ran) {
            check(std::chrono::steady_clock::now() < deadline);
            std::this_thread::yield();
        }
        check(deferred);
        check(lockFree);
        bool direct = false;
        deferDartCallback([&] { direct = true; });  // outside a task: inline
        check(direct);
        JobThread::destroy(std::move(owner));
    }
    // Direct exports can also cause Filament to deliver callbacks (for example
    // flushAndWait). Nested guards must retain them until the OUTERMOST unlock.
    {
        bool delivered = false;
        bool reentered = false;
        {
            EngineApiGuard outer;
            {
                EngineApiGuard inner;
                const int result = 42;
                deferDartCallback([&, result] {
                    check(result == 42); // task-local payload was copied
                    std::thread probe([&] {
                        check(engineApiMutex().try_lock());
                        engineApiMutex().unlock();
                    });
                    probe.join();
                    deferDartCallback([&] { reentered = true; });
                    check(reentered); // no appending to the queue being drained
                    delivered = true;
                });
            }
            check(!delivered);
        }
        check(delivered);
        check(engineApiWaiters() == 0);
    }
    // A callback blocked outside the lock must not stop another worker from
    // running its task and draining its separate thread-local completion queue.
    {
        auto first = JobThread::create();
        auto second = JobThread::create();
        std::promise<void> firstDelivering, secondDelivered, releaseFirst;
        auto firstReady = firstDelivering.get_future();
        auto secondReady = secondDelivered.get_future();
        auto release = releaseFirst.get_future();
        first->addDetachedTask([&] {
            const auto thread = std::this_thread::get_id();
            deferDartCallback([&, thread] {
                check(std::this_thread::get_id() == thread);
                firstDelivering.set_value();
                check(release.wait_for(2s) == std::future_status::ready);
            });
        });
        check(firstReady.wait_for(2s) == std::future_status::ready);
        second->addDetachedTask([&] {
            const auto thread = std::this_thread::get_id();
            deferDartCallback([&, thread] {
                check(std::this_thread::get_id() == thread);
                secondDelivered.set_value();
            });
        });
        check(secondReady.wait_for(2s) == std::future_status::ready);
        releaseFirst.set_value();
        JobThread::destroy(std::move(first));
        JobThread::destroy(std::move(second));
    }
#if defined(__cpp_exceptions) || defined(_CPPUNWIND)
    // Exception-enabled embedders must not leave TLS pointing to a dead queue.
    {
        bool delivered = false;
        try {
            EngineApiGuard guard;
            deferDartCallback([&] { delivered = true; });
            throw std::runtime_error("unwind callback scope");
        } catch (const std::runtime_error&) {
        }
        check(delivered);
        bool inlineAfterUnwind = false;
        deferDartCallback([&] { inlineAfterUnwind = true; });
        check(inlineAfterUnwind);
        check(engineApiWaiters() == 0);

        auto owner = JobThread::create();
        std::promise<void> callbackDone;
        auto callbackReady = callbackDone.get_future();
        std::packaged_task<int()> failing([&]() -> int {
            EngineApiGuard nested;
            deferDartCallback([&] { callbackDone.set_value(); });
            throw std::runtime_error("packaged task failure");
        });
        auto future = owner->addTask(failing);
        check(future.wait_for(2s) == std::future_status::ready);
        bool caught = false;
        try { future.get(); } catch (const std::runtime_error&) { caught = true; }
        check(caught);
        check(callbackReady.wait_for(2s) == std::future_status::ready);
        JobThread::destroy(std::move(owner));
    }
#endif
    std::puts("PASS: FIFO, shutdown, nested guards, reentrant completion, multiple workers, callback scope cleanup");
}
