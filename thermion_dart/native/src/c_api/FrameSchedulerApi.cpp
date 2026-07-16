#include <atomic>
#include <algorithm>
#include <chrono>
#include <thread>

#include "c_api/FrameSchedulerApi.h"
#include "c_api/TRenderManager.h"

#include "rendering/RenderThread.hpp"
#include "rendering/RenderManager.hpp"
#include "rendering/FrameScheduler.hpp"

// Dart API for port-based frame scheduling (hot restart safe)
#ifndef __EMSCRIPTEN__
#include "dart/dart_api_dl.h" // needed for FrameScheduler_initDartApi
#endif

using namespace thermion;

extern "C"
{

  static thermion::FrameScheduler* _frameScheduler = nullptr;

  // Native render loop state
  static TRenderManager* _nativeRenderManager = nullptr;
  static RenderThread* _renderThread = nullptr;  // non-owning; owned by ThermionDartRenderThreadApi
  static std::atomic<bool> _nativeRenderInProgress{false};

  // Process-wide desired cap. It survives scheduler stop/start so lifecycle
  // transitions do not silently discard the user's setting. 0 = unlimited.
  static std::atomic<int> _targetFpsLimit{0};

  // Pacing state for the Linux Flutter-synced request-render path, which
  // bypasses FrameScheduler::dispatchFrame. These fields are only touched on
  // Flutter's UI thread.
  static int _requestAppliedFpsLimit = 0;
  static uint64_t _nextRequestRenderNs = 0;

  static void applyTargetFps(FrameScheduler* scheduler) {
    scheduler->setTargetFps(_targetFpsLimit.load(std::memory_order_relaxed));
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_start(FrameCallback callback, int targetFps) {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }
    _frameScheduler = thermion::FrameScheduler::create(targetFps);
    applyTargetFps(_frameScheduler);
    _frameScheduler->start(callback);
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_stop() {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }
    _nativeRenderManager = nullptr;
    // Wait for any in-progress native render to finish
    while (_nativeRenderInProgress.load()) {
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
#endif
  }

  // Port-based frame scheduler (hot restart safe)
  // When the Dart isolate dies (hot restart), Dart_PostCObject_DL silently
  // drops messages instead of crashing.

#ifndef __EMSCRIPTEN__
  static bool _dartApiInitialized = false;
#endif

  // Returns steady_clock microseconds — call from Dart to measure port transit time
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
    _frameScheduler->startWithPort(port);
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

  // === Native render loop (bypasses Dart event loop) ===

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_setRenderThread(void* renderThread) {
#ifndef __EMSCRIPTEN__
    _renderThread = static_cast<RenderThread*>(renderThread);
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_setRenderManager(TRenderManager* rm) {
    _nativeRenderManager = rm;
  }

  static PostRenderCallback _postRenderCallback = nullptr;
  static void* _postRenderUserData = nullptr;

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_setPostRenderCallback(PostRenderCallback callback, void* userData) {
    _postRenderCallback = callback;
    _postRenderUserData = userData;
  }

  // Frame callback for native render loop — runs on scheduler thread
  static bool _nativeFrameCallback(uint64_t frameTimeNanos) {
    if (!_nativeRenderManager || !_renderThread) return false;
    if (_nativeRenderInProgress.exchange(true)) {
      return false; // skip if still rendering
    }

    std::packaged_task<void()> task([frameTimeNanos]() {
      RenderManager_render(_nativeRenderManager, frameTimeNanos);

      if (_postRenderCallback) {
        _postRenderCallback(_postRenderUserData);
      }

      _nativeRenderInProgress.store(false);
    });
    _renderThread->addTask(task);
    return true;
  }

  // Adapter for FrameScheduler::Callback, whose return type is void.
  static void _nativeScheduledFrameCallback(uint64_t frameTimeNanos) {
    _nativeFrameCallback(frameTimeNanos);
  }

  // Request a single render frame (called from Dart's frame callback).
  // Non-blocking: queues the render to the render thread and returns.
  // Throttled here (not in _nativeFrameCallback) so the Linux Flutter-synced
  // path — which bypasses the FrameScheduler/dispatchFrame throttle — still
  // honors the target fps. display-link/timer/DXGI paths pace themselves in
  // dispatchFrame and don't go through requestRender.
  EMSCRIPTEN_KEEPALIVE bool FrameScheduler_requestRender(uint64_t frameTimeNanos) {
    int fps = _targetFpsLimit.load(std::memory_order_relaxed);
    if (fps > 0) {
      const uint64_t interval = std::max<uint64_t>(
          1, 1000000000ULL / static_cast<uint64_t>(fps));
      const uint64_t tolerance = 1000000ULL; // 1 ms

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
