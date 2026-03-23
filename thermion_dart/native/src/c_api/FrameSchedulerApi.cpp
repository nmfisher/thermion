#include <atomic>
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

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_start(FrameCallback callback, int targetFps) {
#ifndef __EMSCRIPTEN__
    if (_frameScheduler) {
      _frameScheduler->stop();
      delete _frameScheduler;
      _frameScheduler = nullptr;
    }
    _frameScheduler = thermion::FrameScheduler::create(targetFps);
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
    _frameScheduler->startWithPort(port);
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
  static void _nativeFrameCallback(uint64_t frameTimeNanos) {
    if (!_nativeRenderManager || !_renderThread) return;
    if (_nativeRenderInProgress.exchange(true)) return; // skip if still rendering

    std::packaged_task<void()> task([frameTimeNanos]() {
      RenderManager_render(_nativeRenderManager, frameTimeNanos);

      if (_postRenderCallback) {
        _postRenderCallback(_postRenderUserData);
      }

      _nativeRenderInProgress.store(false);
    });
    _renderThread->addTask(task);
  }

  // Request a single render frame (called from Dart's frame callback).
  // Non-blocking: queues the render to the render thread and returns.
  EMSCRIPTEN_KEEPALIVE void FrameScheduler_requestRender(uint64_t frameTimeNanos) {
    _nativeFrameCallback(frameTimeNanos);
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
    _frameScheduler->start(_nativeFrameCallback);
#endif
  }

}
