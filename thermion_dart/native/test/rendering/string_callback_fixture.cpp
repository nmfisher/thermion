#include <chrono>
#include <condition_variable>
#include <mutex>

#ifdef _WIN32
#define TEST_EXPORT extern "C" __declspec(dllexport)
#else
#define TEST_EXPORT extern "C" __attribute__((visibility("default")))
#endif

namespace {
std::mutex mutex;
std::condition_variable condition;
bool completed = false;
}

TEST_EXPORT void resetTaskCompletion() {
    std::lock_guard<std::mutex> lock(mutex);
    completed = false;
}

TEST_EXPORT void markTaskCompleted() {
    std::lock_guard<std::mutex> lock(mutex);
    completed = true;
    condition.notify_one();
}

// Block the Dart isolate until the queued rename or deletion has finished.
// NativeCallable.listener cannot deliver the name while this call is running.
TEST_EXPORT bool waitForTaskCompletion() {
    std::unique_lock<std::mutex> lock(mutex);
    return condition.wait_for(lock, std::chrono::seconds(5), [] { return completed; });
}
