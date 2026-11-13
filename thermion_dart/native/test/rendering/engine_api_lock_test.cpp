// Engine API lock regression (two threads driving one Filament engine).
//
// Loads a built thermion_dart library at runtime (path in argv[1]) and drives
// it the way the Dart side does: the job thread runs queued tasks that write
// transforms and churn transform components, while the calling thread (the
// "Dart" thread) hammers the direct TransformManager exports at the same time.
// Uses the NOOP backend, so no GPU or window is needed.
//
// Without the engine API lock the two threads race inside the transform
// manager (SUSPECTED FTransformManager; e.g. its 16-slot dirty batch) and the
// process crashes or the hierarchy ends up inconsistent. With the lock it
// must stay clean.
//
// Usage: engine_api_lock_test <path to thermion_dart library> [seconds=10]
// Exit codes: 0 pass, 2 setup failure, 3 hierarchy corrupted, 4 lock not held,
// by job-thread tasks, 5/6 starvation (caller wait > 250 ms / < 100 job ticks). A crash shows as the platform's crash exit code.

#include "c_api/TBackend.h"

#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <vector>
#include <algorithm>

#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
using LibHandle = HMODULE;
static LibHandle openLib(const char* p) { return LoadLibraryA(p); }
static void* sym(LibHandle h, const char* n) { return reinterpret_cast<void*>(GetProcAddress(h, n)); }
#else
#include <dlfcn.h>
using LibHandle = void*;
static LibHandle openLib(const char* p) { return dlopen(p, RTLD_NOW); }
static void* sym(LibHandle h, const char* n) { return dlsym(h, n); }
#endif

using namespace std::chrono;
using EntityId = int32_t;

// C API (subset). Signatures mirror include/c_api/*.h.
static void* (*JobThread_create)();
static void (*JobThread_addTask)(void*, void (*)());
static void (*JobThread_destroy)(void*);
static void* (*Engine_create)(int, void*, void*, uint8_t, bool);
static void (*Engine_destroy)(void*);
static void* (*Engine_getTransformManager)(void*);
static void* (*Engine_getEntityManager)(void*);
static EntityId (*EntityManager_createEntity)(void*);
static void (*EntityManager_destroyEntity)(void*, EntityId);
static void (*TM_createComponent)(void*, EntityId);
static void (*TM_removeComponent)(void*, EntityId);
static void (*TM_setParent)(void*, EntityId, EntityId, bool);
static void (*TM_setFromBuffer)(void*, EntityId, const double*);
static void (*TM_getWorldInto)(void*, EntityId, double*);
static void (*TM_getLocalInto)(void*, EntityId, double*);

static void* gEngine = nullptr;
static void* gTm = nullptr;
static void* gEm = nullptr;
static std::atomic<bool> gReady{false};
static std::atomic<bool> gStop{false};
static std::atomic<bool> gHolding{false};
static std::atomic<int> gJobLoops{0};
static std::atomic<bool> gJobDone{false};
static void* gJobThread = nullptr;

constexpr int kChildren = 48;
static EntityId gRootA, gRootB;
static std::vector<EntityId> gKidsA, gKidsB, gPool;

static void translation(double* m, double x, double y, double z) {
    for (int i = 0; i < 16; ++i) m[i] = (i % 5 == 0) ? 1.0 : 0.0;
    m[12] = x; m[13] = y; m[14] = z;
}

static EntityId makeNode(EntityId parent) {
    EntityId e = EntityManager_createEntity(gEm);
    TM_createComponent(gTm, e);
    if (parent) TM_setParent(gTm, e, parent, false);
    double m[16];
    translation(m, 1, 0, 0);
    TM_setFromBuffer(gTm, e, m);
    return e;
}

// --- job-thread tasks (no user data in JobThread_addTask, so globals) ------
static void setupTask() {
    gEngine = Engine_create(BACKEND_NOOP, nullptr, nullptr, 1, false);
    if (gEngine) {
        gTm = Engine_getTransformManager(gEngine);
        gEm = Engine_getEntityManager(gEngine);
        gRootA = makeNode(0);
        gRootB = makeNode(0);
        for (int i = 0; i < kChildren; ++i) {
            // chains of depth 2 so transformChildren recurses
            EntityId a = makeNode(gRootA); gKidsA.push_back(a); gKidsA.push_back(makeNode(a));
            EntityId b = makeNode(gRootB); gKidsB.push_back(b); gKidsB.push_back(makeNode(b));
        }
        for (int i = 0; i < 24; ++i) gPool.push_back(EntityManager_createEntity(gEm));
    }
    gReady = true;
}

// One "render tick": writes transforms under root B and churns components so
// the manager's storage grows and shrinks (like a GLB load creating entities).
static void tickTask() {
    double m[16];
    const int n = gJobLoops.fetch_add(1);
    translation(m, n % 7, 1, 0);
    TM_setFromBuffer(gTm, gRootB, m);
    for (size_t i = 0; i < gKidsB.size(); i += 3) TM_setFromBuffer(gTm, gKidsB[i], m);
    // Fixed entity pool: re-creating entities would exhaust Filament's
    // entity ids (index + 8-bit generation) within ~100k cycles.
    for (EntityId e : gPool) {
        TM_createComponent(gTm, e);
        TM_setParent(gTm, e, gRootB, false);
        TM_setFromBuffer(gTm, e, m);
    }
    for (EntityId e : gPool) TM_removeComponent(gTm, e);
    if (!gStop) JobThread_addTask(gJobThread, tickTask);
    else gJobDone = true;
}

static void holdTask() {
    gHolding = true;
    std::this_thread::sleep_for(milliseconds(300));
    gHolding = false;
}

static void teardownTask() {
    Engine_destroy(gEngine);
    gReady = false;
}

template <class F>
static bool waitFor(F f, milliseconds budget) {
    auto end = steady_clock::now() + budget;
    while (!f()) {
        if (steady_clock::now() > end) return false;
        std::this_thread::sleep_for(milliseconds(1));
    }
    return true;
}

#define LOAD(var, name)                                                         \
    var = reinterpret_cast<decltype(var)>(sym(lib, name));                      \
    if (!var) { std::fprintf(stderr, "missing export %s\n", name); return 2; }

int main(int argc, char** argv) {
    if (argc < 2) { std::fprintf(stderr, "usage: %s <thermion_dart lib> [seconds]\n", argv[0]); return 2; }
    std::setvbuf(stdout, nullptr, _IONBF, 0);
    const int seconds = argc > 2 ? std::atoi(argv[2]) : 10;
    LibHandle lib = openLib(argv[1]);
    if (!lib) { std::fprintf(stderr, "cannot load %s\n", argv[1]); return 2; }
    LOAD(JobThread_create, "JobThread_create");
    LOAD(JobThread_addTask, "JobThread_addTask");
    LOAD(JobThread_destroy, "JobThread_destroy");
    LOAD(Engine_create, "Engine_create");
    LOAD(Engine_destroy, "Engine_destroy");
    LOAD(Engine_getTransformManager, "Engine_getTransformManager");
    LOAD(Engine_getEntityManager, "Engine_getEntityManager");
    LOAD(EntityManager_createEntity, "EntityManager_createEntity");
    LOAD(EntityManager_destroyEntity, "EntityManager_destroyEntity");
    LOAD(TM_createComponent, "TransformManager_createComponent");
    LOAD(TM_removeComponent, "TransformManager_removeComponent");
    LOAD(TM_setParent, "TransformManager_setParent");
    LOAD(TM_setFromBuffer, "TransformManager_setTransformFromBuffer");
    LOAD(TM_getWorldInto, "TransformManager_getWorldTransformInto");
    LOAD(TM_getLocalInto, "TransformManager_getLocalTransformInto");

    gJobThread = JobThread_create();
    JobThread_addTask(gJobThread, setupTask);
    if (!waitFor([] { return gReady.load(); }, milliseconds(30000))) return 2;
    if (!gEngine) { std::fprintf(stderr, "Engine_create(NOOP) failed\n"); return 2; }

    // 1. Does a running job-thread task exclude the direct exports?
    JobThread_addTask(gJobThread, holdTask);
    if (!waitFor([] { return gHolding.load(); }, milliseconds(5000))) return 2;
    auto t0 = steady_clock::now();
    double out[16];
    TM_getWorldInto(gTm, gRootA, out);
    const double blockedMs = duration<double, std::milli>(steady_clock::now() - t0).count();
    const bool lockHeld = blockedMs >= 100.0;
    std::printf("direct getter during a 300 ms job task waited %.1f ms -> %s\n",
                blockedMs, lockHeld ? "LOCKED" : "NOT LOCKED");
    waitFor([] { return !gHolding.load(); }, milliseconds(5000));

    // 2. Stress: job thread ticks while this thread hammers direct exports.
    std::puts("stress: start");
    JobThread_addTask(gJobThread, tickTask);
    auto end = steady_clock::now() + std::chrono::seconds(seconds);
    long calls = 0;
    double maxWaitMs = 0;
    std::vector<double> samples;
    int n = 0;
    while (steady_clock::now() < end) {
        double m[16];
        translation(m, 0, (n++ % 11) * 0.5, 0);
        auto s = steady_clock::now();
        TM_setFromBuffer(gTm, gRootA, m);                 // transformChildren on 96 nodes
        TM_getWorldInto(gTm, gKidsA[n % gKidsA.size()], out);
        const double w = duration<double, std::milli>(steady_clock::now() - s).count();
        maxWaitMs = std::max(maxWaitMs, w);
        if ((calls & 63) == 0) samples.push_back(w);
        ++calls;
    }
    gStop = true;
    waitFor([] { return gJobDone.load(); }, milliseconds(10000));

    // 3. Consistency: every child of A must be parent world * local.
    int bad = 0;
    for (size_t i = 0; i < gKidsA.size(); i += 2) {
        double pw[16], cw[16], cl[16], gl[16], gw[16];
        TM_getWorldInto(gTm, gKidsA[i], cw);
        TM_getWorldInto(gTm, gRootA, pw);
        TM_getLocalInto(gTm, gKidsA[i], cl);
        // translations only: world.t = parent.t + local.t
        for (int k = 12; k < 15; ++k) if (std::fabs(cw[k] - (pw[k] + cl[k])) > 1e-3) { ++bad; break; }
        TM_getWorldInto(gTm, gKidsA[i + 1], gw);
        TM_getLocalInto(gTm, gKidsA[i + 1], gl);
        for (int k = 12; k < 15; ++k) if (std::fabs(gw[k] - (cw[k] + gl[k])) > 1e-3) { ++bad; break; }
    }
    std::sort(samples.begin(), samples.end());
    const double p99 = samples.empty() ? 0 : samples[std::min(samples.size() - 1, size_t(samples.size() * 0.99))];
    std::printf("stress %d s: direct call pairs=%ld, job ticks=%d, caller wait max=%.2f ms p99=%.3f ms, "
                "hierarchy mismatches=%d\n",
                seconds, calls, gJobLoops.load(), maxWaitMs, p99, bad);

    JobThread_addTask(gJobThread, teardownTask);
    waitFor([] { return !gReady.load(); }, milliseconds(10000));
    JobThread_destroy(gJobThread);
    if (bad) { std::puts("FAIL: hierarchy corrupted"); return 3; }
    if (!lockHeld) { std::puts("FAIL: job-thread task does not hold the engine API lock"); return 4; }
    // A tick is a few ms of work; a direct caller must never wait much longer.
    if (maxWaitMs > 250.0) { std::puts("FAIL: direct caller starved by the job thread"); return 5; }
    if (gJobLoops.load() < 100) { std::puts("FAIL: job thread starved by the direct caller"); return 6; }
    std::puts("PASS: engine API lock serialises job-thread tasks and direct exports");
    return 0;
}
