#include <stdexcept>

#ifdef _WIN32
#define TEST_EXPORT extern "C" __declspec(dllexport)
#else
#define TEST_EXPORT extern "C" __attribute__((visibility("default")))
#endif

// Passed to the production RenderThread_addTask by the Dart integration tests.
// Throw on the render worker, never across a Dart-to-native FFI call.
TEST_EXPORT void throwTaskError() {
    throw std::runtime_error("expected native task failure");
}

TEST_EXPORT void throwUnknownTaskError() {
    throw 42;
}
