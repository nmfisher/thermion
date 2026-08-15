#include <algorithm>
#include <atomic>
#include <chrono>
#include <mutex>
#include <vector>

#include "c_api/FrameSchedulerApi.h"

#include "rendering/FrameScheduler.hpp"

#ifndef __EMSCRIPTEN__
#include "dart/dart_api_dl.h"
#endif

using namespace thermion;

extern "C"
{

  static thermion::FrameScheduler* _frameScheduler = nullptr;

  // --- Multi-client registry (two engines in one process) -------------------
  // The native scheduler is a process-wide singleton, but each Flutter engine
  // (primary window, popout windows) runs its own Dart isolate with its own
  // FrameScheduler facade. Clients register through
  // FrameScheduler_startWithCallback / FrameScheduler_startWithPort; one shared
  // scheduler fans frames out to all of them via _fanoutFrameCallback. A dead
  // port (its isolate died in a hot restart or a closed window) is pruned on
  // its first failed post. The scheduler is torn down when the last client
  // deregisters through FrameScheduler_removePort /
  // FrameScheduler_removeCallback.
  //
  // Lock order: _schedulerLifecycleMutex (outer) -> _frameClientsMutex
  // (inner). The dispatch thread only ever takes the inner mutex, so a
  // lifecycle holder joining the dispatch thread cannot deadlock.
  //
  // Only PORT clients may register from a Flutter engine (any build mode):
  // an isolate can die without deregistering - hot restart, or a popout
  // window closing without a clean FilamentApp.destroy - and a dead port is
  // detectable (Dart_PostCObject_DL returns false) while a dead
  // NativeCallable trampoline is not. Direct-callback clients have no
  // liveness check and exist for non-Flutter embedders that own their
  // process lifetime.
  struct FrameClient {
    FrameTickCallback callback; // nullptr for port clients
    int64_t port;               // 0 for callback clients
  };
  static std::mutex _schedulerLifecycleMutex;
  static std::mutex _frameClientsMutex;
  static std::vector<FrameClient> _frameClients;

  static std::atomic<int> _targetFpsLimit{0};

  static void applyTargetFps(FrameScheduler* scheduler) {
    scheduler->setTargetFps(_targetFpsLimit.load(std::memory_order_relaxed));
  }

#ifndef __EMSCRIPTEN__
  static void _fanoutFrameCallback(uint64_t frameTimeNanos, void* /*userData*/) {
    std::lock_guard<std::mutex> lock(_frameClientsMutex);
    for (auto it = _frameClients.begin(); it != _frameClients.end();) {
      if (it->callback) {
        it->callback(frameTimeNanos);
        ++it;
        continue;
      }
      if (Dart_PostCObject_DL == nullptr) {
        // Dart_InitializeApiDL never succeeded; this port can never be
        // reached. Drop the client instead of dereferencing null.
        it = _frameClients.erase(it);
        continue;
      }
      Dart_CObject msg;
      msg.type = Dart_CObject_kInt64;
      msg.value.as_int64 = static_cast<int64_t>(frameTimeNanos);
      if (Dart_PostCObject_DL(it->port, &msg)) {
        ++it;
      } else {
        // The receiving isolate is gone (hot restart / closed window).
        it = _frameClients.erase(it);
      }
    }
    // Never stop/delete the scheduler from inside its own dispatch: platform
    // stop() implementations join the dispatch thread. An empty registry just
    // dispatches to nobody until the next registration or an explicit
    // FrameScheduler_stop().
  }

  // Caller must hold _schedulerLifecycleMutex.
  static void _ensureSchedulerStartedLocked(int targetFps) {
    if (_frameScheduler) return; // already running with the fan-out callback
    _frameScheduler = thermion::FrameScheduler::create(targetFps);
    applyTargetFps(_frameScheduler);
    _frameScheduler->start(_fanoutFrameCallback, nullptr);
  }

  // Caller must hold _schedulerLifecycleMutex.
  static void _stopSchedulerLocked() {
    if (!_frameScheduler) return;
    _frameScheduler->stop();
    delete _frameScheduler;
    _frameScheduler = nullptr;
  }

  static bool _dartApiInitialized = false;
#endif

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_startWithCallback(
      FrameTickCallback tickCallback, int targetFps) {
#ifndef __EMSCRIPTEN__
    std::lock_guard<std::mutex> lifecycle(_schedulerLifecycleMutex);
    {
      std::lock_guard<std::mutex> lock(_frameClientsMutex);
      bool present = false;
      for (const auto& client : _frameClients) {
        if (client.callback == tickCallback) {
          present = true;
          break;
        }
      }
      if (!present) {
        _frameClients.push_back(FrameClient{tickCallback, 0});
      }
    }
    _ensureSchedulerStartedLocked(targetFps);
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_stop() {
#ifndef __EMSCRIPTEN__
    // Legacy remove-everything teardown. With more than one live engine this
    // stops every window's frame loop - per-client removal goes through
    // FrameScheduler_removePort / FrameScheduler_removeCallback instead.
    std::lock_guard<std::mutex> lifecycle(_schedulerLifecycleMutex);
    {
      std::lock_guard<std::mutex> lock(_frameClientsMutex);
      _frameClients.clear();
    }
    _stopSchedulerLocked();
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_removePort(int64_t port) {
#ifndef __EMSCRIPTEN__
    std::lock_guard<std::mutex> lifecycle(_schedulerLifecycleMutex);
    bool empty;
    {
      std::lock_guard<std::mutex> lock(_frameClientsMutex);
      _frameClients.erase(
          std::remove_if(_frameClients.begin(), _frameClients.end(),
                         [port](const FrameClient& client) {
                           return client.callback == nullptr &&
                                  client.port == port;
                         }),
          _frameClients.end());
      empty = _frameClients.empty();
    }
    if (empty) {
      _stopSchedulerLocked();
    }
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_removeCallback(FrameTickCallback callback) {
#ifndef __EMSCRIPTEN__
    std::lock_guard<std::mutex> lifecycle(_schedulerLifecycleMutex);
    bool empty;
    {
      std::lock_guard<std::mutex> lock(_frameClientsMutex);
      _frameClients.erase(
          std::remove_if(_frameClients.begin(), _frameClients.end(),
                         [callback](const FrameClient& client) {
                           return client.callback == callback;
                         }),
          _frameClients.end());
      empty = _frameClients.empty();
    }
    if (empty) {
      _stopSchedulerLocked();
    }
#endif
  }

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
    std::lock_guard<std::mutex> lifecycle(_schedulerLifecycleMutex);
    {
      std::lock_guard<std::mutex> lock(_frameClientsMutex);
      bool present = false;
      for (const auto& client : _frameClients) {
        if (client.callback == nullptr && client.port == port) {
          present = true;
          break;
        }
      }
      if (!present) {
        _frameClients.push_back(FrameClient{nullptr, port});
      }
    }
    // The scheduler always runs in callback mode with the fan-out trampoline;
    // ports are posted to from the trampoline, not by the scheduler itself.
    _ensureSchedulerStartedLocked(targetFps);
#endif
  }

  EMSCRIPTEN_KEEPALIVE void FrameScheduler_setTargetFps(int fps) {
    int normalizedFps = fps > 0 ? fps : 0;
    _targetFpsLimit.store(normalizedFps, std::memory_order_relaxed);
#ifndef __EMSCRIPTEN__
    // The cap is process-wide: with two engines registered the shared
    // scheduler dispatches at one rate for both windows.
    std::lock_guard<std::mutex> lifecycle(_schedulerLifecycleMutex);
    if (_frameScheduler) {
      _frameScheduler->setTargetFps(normalizedFps);
    }
#endif
  }

}
