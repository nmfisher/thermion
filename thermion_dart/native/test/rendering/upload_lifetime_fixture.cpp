#include <atomic>
#include <chrono>
#include <thread>

#ifdef _WIN32
#define TEST_EXPORT extern "C" __declspec(dllexport)
#else
#define TEST_EXPORT extern "C" __attribute__((visibility("default")))
#endif

// Hold the render worker so Dart can verify release has not yet been signalled.
namespace { std::atomic<bool> releaseTask{false}; }
TEST_EXPORT void resetTaskRelease() { releaseTask.store(false); }
TEST_EXPORT void allowTaskToFinish() { releaseTask.store(true); }
TEST_EXPORT void waitForTaskRelease() {
    while (!releaseTask.load()) std::this_thread::sleep_for(std::chrono::milliseconds(1));
}
