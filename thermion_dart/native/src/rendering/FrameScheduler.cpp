#include "rendering/FrameScheduler.hpp"
#include "Log.hpp"

namespace thermion {

// ---------------------------------------------------------------------------
// TimerFrameScheduler
// ---------------------------------------------------------------------------

void TimerFrameScheduler::start(Callback callback) {
    if (_running) return;
    _running = true;
    auto interval = std::chrono::nanoseconds(1000000000 / _targetFps);
    _thread = new std::thread([this, callback, interval]() {
        while (_running) {
            auto start = std::chrono::high_resolution_clock::now();
            uint64_t nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                start.time_since_epoch()).count();
            callback(nanos);
            auto elapsed = std::chrono::high_resolution_clock::now() - start;
            if (elapsed < interval) {
                std::this_thread::sleep_for(interval - elapsed);
            }
        }
    });
}

void TimerFrameScheduler::stop() {
    _running = false;
    if (_thread) {
        _thread->join();
        delete _thread;
        _thread = nullptr;
    }
}

} // namespace thermion
