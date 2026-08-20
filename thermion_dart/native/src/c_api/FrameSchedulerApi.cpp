#include <atomic>
#include <algorithm>
#include <chrono>
#include <thread>

#include "c_api/FrameSchedulerApi.h"
#include "c_api/TRenderManager.h"

#include "rendering/RenderThread.hpp"
#include "rendering/RenderManager.hpp"
#include "rendering/FrameScheduler.hpp"

#ifndef __EMSCRIPTEN__
#include "dart/dart_api_dl.h"
#endif

using namespace thermion;

extern "C"
{

  static thermion::FrameScheduler* _frameScheduler = nullptr;
  static FrameCallback _scheduledCallback = nullptr;
  static int64_t _dartPort = 0;

  static TRenderManager* _nativeRenderManager = nullptr;
  static RenderThread* _renderThread = nullptr;
  static std::atomic<bool> _nativeRenderInProgress{false};
  static PostRenderCallback _postRenderCallback = nullptr;
  static void* _postRenderUserData = nullptr;

  static std::atomic<int> _targetFpsLimit{0};

  static int _requestAppliedFpsLimit = 0;
  static uint64_t _nextRequestRenderNs = 0;

  static void applyTargetFps(FrameScheduler* scheduler) {
    scheduler->setTargetFps(_targetFpsLimit.load(std::memory_order_relaxed));
  }

  static void forwardScheduledFrame(
      uint64_t frameTimeNanos, void* userData) {
    auto callback = *static_cast<FrameCallback*>(userData);
    if (callback) {
      callback(frameTimeNanos);
    }
  }

#ifndef __EMSCRIPTEN__
  static void postScheduledFrameToDart(
      uint64_t frameTimeNanos, void* userData) {
    const int64_t port = *static_cast<int64_t*>(userData);
    if (port == 0) return;

    Dart_CObject message;
    message.type = Dart_CObject_kInt64;
    message.value.as_int64 = static_cast<int64_t>(frameTimeNanos);
    Dart_PostCObject_DL(port, &message);
  }
#endif

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_start(FrameCallback callback, int targetFps) {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }
    _frameScheduler = thermion::FrameScheduler::create(targetFps);
    applyTargetFps(_frameScheduler);
    _scheduledCallback = callback;
    _frameScheduler->start(forwardScheduledFrame, &_scheduledCallback);
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_stop() {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }
    _scheduledCallback = nullptr;
    _dartPort = 0;

    while (_nativeRenderInProgress.load(std::memory_order_acquire)) {
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    _nativeRenderManager = nullptr;
    _renderThread = nullptr;
    _postRenderCallback = nullptr;
    _postRenderUserData = nullptr;
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
    _frameScheduler->start(postScheduledFrameToDart, &_dartPort);
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

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_setRenderThread(void* renderThread) {
#ifndef __EMSCRIPTEN__
    _renderThread = static_cast<RenderThread*>(renderThread);
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_setRenderManager(TRenderManager* rm) {
    _nativeRenderManager = rm;
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_setPostRenderCallback(PostRenderCallback callback, void* userData) {
    _postRenderCallback = callback;
    _postRenderUserData = userData;
  }

  static bool _nativeFrameCallback(uint64_t frameTimeNanos) {
    auto* renderManager = _nativeRenderManager;
    auto* renderThread = _renderThread;
    auto postRenderCallback = _postRenderCallback;
    auto* postRenderUserData = _postRenderUserData;
    if (!renderManager || !renderThread) return false;
    if (_nativeRenderInProgress.exchange(true, std::memory_order_acq_rel)) {
      return false;
    }

    renderThread->addDetachedTask([
      renderManager,
      frameTimeNanos,
      postRenderCallback,
      postRenderUserData
    ]() {
      RenderManager_render(renderManager, frameTimeNanos);

      if (postRenderCallback) {
        postRenderCallback(postRenderUserData);
      }

      _nativeRenderInProgress.store(false, std::memory_order_release);
    });
    return true;
  }

  static void _nativeScheduledFrameCallback(
      uint64_t frameTimeNanos, void*) {
    _nativeFrameCallback(frameTimeNanos);
  }

  EMSCRIPTEN_KEEPALIVE bool FrameScheduler_requestRender(uint64_t frameTimeNanos) {
    int fps = _targetFpsLimit.load(std::memory_order_relaxed);
    if (fps > 0) {
      const uint64_t interval = std::max<uint64_t>(
          1, 1000000000ULL / static_cast<uint64_t>(fps));
      const uint64_t tolerance = 1000000ULL;

      if (_requestAppliedFpsLimit != fps || _nextRequestRenderNs == 0) {
        _requestAppliedFpsLimit = fps;
        _nextRequestRenderNs = frameTimeNanos;
      }

      if (_nextRequestRenderNs > frameTimeNanos &&
          _nextRequestRenderNs - frameTimeNanos > tolerance) {
        return false;
      }

      if (!_nativeFrameCallback(frameTimeNanos)) {
        return false;
      }

      if (_nextRequestRenderNs <= frameTimeNanos) {
        const uint64_t missedIntervals =
            (frameTimeNanos - _nextRequestRenderNs) / interval + 1;
        _nextRequestRenderNs += missedIntervals * interval;
      } else {
        _nextRequestRenderNs += interval;
      }
      return true;
    } else {
      _requestAppliedFpsLimit = 0;
      _nextRequestRenderNs = 0;
    }
    return _nativeFrameCallback(frameTimeNanos);
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_startNativeRenderLoop(int targetFps) {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }

    _frameScheduler = new thermion::TimerFrameScheduler(
        targetFps > 0 ? targetFps : 60);
    applyTargetFps(_frameScheduler);
    _frameScheduler->start(_nativeScheduledFrameCallback);
#endif
  }

}
