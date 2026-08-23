#include <atomic>
#include <chrono>

#include "c_api/FrameSchedulerApi.h"

#include "rendering/FrameScheduler.hpp"

#ifndef __EMSCRIPTEN__
#include "dart/dart_api_dl.h"
#endif

using namespace thermion;

extern "C"
{

  static thermion::FrameScheduler* _frameScheduler = nullptr;
  static FrameTickCallback _tickCallback = nullptr;
  static int64_t _dartPort = 0;

  static std::atomic<int> _targetFpsLimit{0};

  static void applyTargetFps(FrameScheduler* scheduler) {
    scheduler->setTargetFps(_targetFpsLimit.load(std::memory_order_relaxed));
  }

  static void forwardScheduledTick(
      uint64_t frameTimeNanos, void* userData) {
    auto callback = *static_cast<FrameTickCallback*>(userData);
    if (callback) {
      callback(frameTimeNanos);
    }
  }

#ifndef __EMSCRIPTEN__
  static void postScheduledTickToDart(
      uint64_t frameTimeNanos, void* userData) {
    const int64_t port = *static_cast<int64_t*>(userData);
    if (port == 0) return;

    Dart_CObject message;
    message.type = Dart_CObject_kInt64;
    message.value.as_int64 = static_cast<int64_t>(frameTimeNanos);
    Dart_PostCObject_DL(port, &message);
  }
#endif

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithCallback(
      FrameTickCallback tickCallback, int targetFps) {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }
    _frameScheduler = thermion::FrameScheduler::create(targetFps);
    applyTargetFps(_frameScheduler);
    _tickCallback = tickCallback;
    _frameScheduler->start(forwardScheduledTick, &_tickCallback);
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_stop() {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }
    _tickCallback = nullptr;
    _dartPort = 0;
#endif
  }

#ifndef __EMSCRIPTEN__
  static bool _dartApiInitialized = false;
#endif

  EMSCRIPTEN_KEEPALIVE int64_t FrameScheduler_steadyClockUs() {
    return std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
  }

  EMSCRIPTEN_KEEPALIVE int FrameScheduler_initDartApi(void* data) {
#ifndef __EMSCRIPTEN__
    if (!_dartApiInitialized && data != nullptr) {
      intptr_t result = Dart_InitializeApiDL(data);
      _dartApiInitialized = (result == 0);
      return _dartApiInitialized ? 0 : -1;
    }
    return _dartApiInitialized ? 0 : -1;
#else
    return -1;
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithPort(int64_t port, int targetFps) {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }
    _frameScheduler = thermion::FrameScheduler::create(targetFps);
    applyTargetFps(_frameScheduler);
    _dartPort = port;
    _frameScheduler->start(postScheduledTickToDart, &_dartPort);
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_setTargetFps(int fps) {
    int normalizedFps = fps > 0 ? fps : 0;
    _targetFpsLimit.store(normalizedFps, std::memory_order_relaxed);
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->setTargetFps(normalizedFps);
    }
#endif
  }

}
