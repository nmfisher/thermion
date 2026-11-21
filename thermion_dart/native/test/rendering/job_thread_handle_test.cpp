#include <cmath>
#include "c_api/ThermionDartJobThreadApi.h"
#include <chrono>
#include <cstdlib>
#include <future>
#include <thread>
#include <type_traits>

using namespace thermion;
using namespace std::chrono_literals;

static_assert(std::is_same_v<decltype(JobThread_create()), TJobThread*>);
static_assert(!std::is_invocable_v<decltype(&JobThread_destroy), TEngine*>);

static std::promise<void> started;
static std::promise<void> releaseFirst;
static std::shared_future<void> released = releaseFirst.get_future().share();
static std::promise<std::thread::id> firstDone;
static std::promise<std::thread::id> secondDone;
static std::promise<std::thread::id> afterDestroy;

static void check(bool condition) {
    if (!condition) std::abort();
}

static void holdFirst() {
    started.set_value();
    check(released.wait_for(5s) == std::future_status::ready);
}

static void finishFirst() { firstDone.set_value(std::this_thread::get_id()); }
static void finishSecond() { secondDone.set_value(std::this_thread::get_id()); }
static void finishAfterDestroy() { afterDestroy.set_value(std::this_thread::get_id()); }

int main() {
    auto* first = JobThread_create();
    auto* second = JobThread_create();
    check(first && second && first != second);

    auto ready = started.get_future();
    auto firstResult = firstDone.get_future();
    auto secondResult = secondDone.get_future();
    JobThread_addTask(first, holdFirst);
    check(ready.wait_for(5s) == std::future_status::ready);

    // B already exists. Submissions to A must still wait behind A's held job.
    JobThread_addTask(first, finishFirst);
    JobThread_addTask(second, finishSecond);
    check(secondResult.wait_for(5s) == std::future_status::ready);
    check(firstResult.wait_for(0s) == std::future_status::timeout);
    releaseFirst.set_value();
    check(firstResult.wait_for(5s) == std::future_status::ready);
    const auto firstId = firstResult.get();
    check(firstId != secondResult.get());
    check(firstId != std::this_thread::get_id());

    // Destroying B must leave A usable.
    JobThread_destroy(second);
    auto last = afterDestroy.get_future();
    JobThread_addTask(first, finishAfterDestroy);
    check(last.wait_for(5s) == std::future_status::ready);
    check(last.get() == firstId);
    JobThread_destroy(first);
}
