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
//   1. The lock is only ever held for the duration of one export call or one
//      job-thread task. Exports never wait on the job thread (they do not
//      enqueue-and-wait), and job-thread tasks never wait on the caller's
//      thread: results go back through NativeCallable.listener callbacks,
//      which post to the Dart event loop and return immediately.
//   2. Lock order is always engine-API lock first. The other native locks
//      (RenderManager::mMutex, AnimationManager::mMutex, the texture-provider
//      and frame-scheduler mutexes, EngineLifecycle) are taken inside it, or
//      on paths that do not hold the engine-API lock (frame scheduler thread,
//      Flutter raster/blit threads, Filament's driver and JobSystem threads).
//      The Dart/platform thread does take the engine-API lock for direct
//      exports; it does not hold another native lock across one.
//   3. Filament-internal waits made while holding it (flushAndWait, fences)
//      wait on Filament's driver thread, which never takes this lock; buffer
//      release callbacks only free memory or post to Dart.
//
// Exports that deliberately stay unguarded: JobThread_* (they join/enqueue the
// job thread), *JobThread enqueue wrappers, EngineLifecycle_*, the frame
// scheduler/telemetry APIs, RenderManager_setPaused/setTargetFps (atomics; a
// pause must not wait for a frame), the TSWAP_CHAIN_CONFIG_* constant exports
// (no Engine access), and pure-CPU helpers that never touch an Engine (Image_*,
// Ktx1Bundle_*, TextureSampler_*, Mat4_*, SurfaceOrientation*, GltfParser_*,
// MeshData_*, Material_get*Version).
//
// Web (Emscripten) builds compile the guard to nothing: there the engine is
// owned by one worker (or the main thread) and the direct exports are not
// called from a second thread.

#if defined(__EMSCRIPTEN__)

#define THERMION_ENGINE_API_GUARD ((void)0)

#else

#include <atomic>
#include <mutex>

namespace thermion {

// Process-wide, never destroyed (function-local leaked statics, so nothing
// runs at DLL unload and no static-destruction-order hazard exists).
std::recursive_mutex& engineApiMutex();

// Number of direct callers currently acquiring or waiting for
// engineApiMutex(). The job
// thread runs tasks back to back; std::recursive_mutex is not fair, so
// without a handoff a busy queue (GLB loads, many queued setters) re-takes the
// lock between tasks and starves the caller's thread for seconds. Before
// taking the lock for its next task the job thread waits until this is 0.
std::atomic<int>& engineApiWaiters();

class EngineApiGuard {
public:
    EngineApiGuard() {
        auto& waiters = engineApiWaiters();
        waiters.fetch_add(1, std::memory_order_acq_rel);
        try {
            engineApiMutex().lock();
        } catch (...) {
            waiters.fetch_sub(1, std::memory_order_acq_rel);
            throw;
        }
        waiters.fetch_sub(1, std::memory_order_acq_rel);
    }
    ~EngineApiGuard() { engineApiMutex().unlock(); }
    EngineApiGuard(const EngineApiGuard&) = delete;
    EngineApiGuard& operator=(const EngineApiGuard&) = delete;
};

} // namespace thermion

#define THERMION_ENGINE_API_GUARD                                              \
    ::thermion::EngineApiGuard thermionEngineApiGuard_

#endif
