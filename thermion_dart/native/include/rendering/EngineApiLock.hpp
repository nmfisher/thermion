#pragma once

// Engine API lock (native platforms).
//
// Filament's Engine and its component managers (TransformManager,
// RenderableManager, LightManager, MaterialInstance, Camera, View, Scene, ...)
// are not thread-safe. Thermion drives them from two threads:
//
//   * the job thread (NativeJobThread::run), which runs every queued
//     *JobThread task, the per-frame render tick and the glTF animation update;
//   * the caller's thread (the Dart isolate thread), through the direct,
//     synchronous C exports (TransformManager_setTransform,
//     MaterialInstance_setParameter*, LightManager_set*, ...).
//
// Without a lock those two interleave inside Filament and corrupt its state
// (e.g. a transform manager's 16-slot dirty batch, SUSPECTED FTransformManager,
// overrun by two writers).
//
// The fix serialises both sides on one process-wide recursive mutex:
//
//   * NativeJobThread::run holds it around each task (never while waiting on
//     its queue condition variable);
//   * every direct C export that touches Filament state takes it with
//     THERMION_ENGINE_API_GUARD at the top of its body.
//
// Recursive, because job-thread tasks call the same direct exports (the
// *JobThread wrappers forward to them) and exports call other exports.
//
// Deadlock argument (see also the commit message):
//   1. Never enqueue work and wait for it while holding this lock: the worker
//      needs the same lock to execute that work. An enqueue-and-wait export
//      (such as #427's MaterialCompiler_compileMaterialSource) must remain
//      unguarded on the submitting side; the queued task acquires the lock.
//      Such an export must not be called from a job task either, unless it
//      detects that case and performs the operation inline.
//      Never call into Dart while holding it: a NativeCallable.listener call
//      from the job thread can block inside
//      the Dart VM until the isolate's thread makes progress (observed on
//      Windows), so every Dart completion raised inside a task goes through
//      deferDartCallback() and runs after the outermost EngineApiGuard releases
//      the lock. This also covers callbacks raised by direct exports.
//   2. Lock order is always engine-API lock first. The other native locks
//      (RenderManager::mMutex, AnimationManager::mMutex, the texture-provider
//      and frame-scheduler mutexes) are taken inside it, or
//      on paths that do not hold the engine-API lock (frame scheduler thread,
//      Flutter raster/blit threads, Filament's driver and JobSystem threads).
//      The Dart/platform thread does take the engine-API lock for direct
//      exports; it does not hold another native lock across one.
//   3. Filament-internal waits made while holding it (flushAndWait, fences)
//      wait on Filament's driver thread, which never takes this lock; buffer
//      release callbacks only free memory or post to Dart.
//
// Exports that deliberately stay unguarded: JobThread_* (they join/enqueue the
// job thread), *JobThread enqueue wrappers, the frame
// scheduler/telemetry APIs, RenderManager_setPaused/setTargetFps (atomics; a
// pause must not wait for a frame), the TSWAP_CHAIN_CONFIG_* constant exports
// (no Engine access), and pure-CPU helpers that never touch an Engine (Image_*,
// Ktx1Bundle_*, TextureSampler_*, Mat4_*, SurfaceOrientation*, GltfParser_*,
// MeshData_*, Material_get*Version).
//
// Web (Emscripten) builds compile the guard to nothing. Main-thread builds
// serialize frontend work on the browser thread. Worker builds still require
// callers to route frontend access through the worker queue; this native lock
// does not fix main-thread direct exports racing worker tasks. Enabling a
// blocking mutex on the browser thread is not a substitute for that routing.

#if defined(__EMSCRIPTEN__)

#define THERMION_ENGINE_API_GUARD ((void)0)

#include <functional>
namespace thermion {
// Web dispatches Dart completions through its own proxy queue; run inline.
inline void deferDartCallback(std::function<void()> fn) { fn(); }
} // namespace thermion

#else

#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

namespace thermion {

// Recursive for nested exports on the owning thread, FIFO for queued callers.
// Waiting nodes live on their calling thread's stack; no per-call allocation.
class EngineApiMutex {
public:
    void lock();
    bool try_lock();
    void unlock();

private:
    struct Waiter {
        explicit Waiter(EngineApiMutex& mutex);
        ~Waiter();
        EngineApiMutex& mutex;
        Waiter* previous;
        Waiter* next = nullptr;
    };

    std::mutex mMutex;
    std::condition_variable mReady;
    std::thread::id mOwner;
    unsigned mDepth = 0;
    Waiter* mFirst = nullptr;
    Waiter* mLast = nullptr;
};

// Process-wide, never destroyed: no DLL-unload destruction-order dependency.
EngineApiMutex& engineApiMutex();

// Number of queued outer acquisitions; recursive entries do not join the queue.
std::atomic<int>& engineApiWaiters();

// Never call into Dart while holding engineApiMutex(). A Dart completion
// (NativeCallable.listener) invoked from the job thread can block inside the
// Dart VM until the isolate's own thread makes progress; if that thread is
// waiting for this lock in a direct export, both stop (seen on Windows: the
// job thread parked in flutter_windows, the platform thread in
// LightManager_setPosition). Inside any EngineApiGuard this queues fn until
// the outermost guard releases the lock, in order on the same thread. Without
// a guard on the calling thread it runs fn immediately, even if another thread
// is in a guarded task. Captures must own their data, and callback registrations
// must remain alive until delivery; copying a raw pointer does not retain it.
void deferDartCallback(std::function<void()> fn);

class EngineApiGuard {
public:
    EngineApiGuard();
    ~EngineApiGuard();
    EngineApiGuard(const EngineApiGuard&) = delete;
    EngineApiGuard& operator=(const EngineApiGuard&) = delete;

private:
    // Only the outermost guard publishes its queue in thread-local storage.
    // Nested exports append there and cannot deliver while an outer lock lives.
    std::vector<std::function<void()>> mDartCallbacks;
    std::vector<std::function<void()>>* mPreviousDartCallbacks = nullptr;
};

} // namespace thermion

#define THERMION_ENGINE_API_GUARD                                              \
    ::thermion::EngineApiGuard thermionEngineApiGuard_

#endif
