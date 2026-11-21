// Browser integration helpers for the real RenderManager / Filament pipeline.
// Compiled only when web_frame_fixture.cmake is explicitly supplied to CMake.
#include "rendering/JobThread.hpp"
#include "c_api/APIBoundaryTypes.h"
#include "rendering/RenderManager.hpp"
#include <filament/Engine.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/View.h>
#include <utils/EntityManager.h>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <thread>
#include <emscripten.h>
#include <emscripten/html5.h>

using namespace thermion;

struct TestScene {
    filament::SwapChain* swapChain = nullptr;
    filament::View* view = nullptr;
    filament::Scene* scene = nullptr;
    utils::Entity camera;
};
// Each slot is accessed only on its owning worker.
static TestScene scenes[2];
static std::atomic<bool> resumeCreation{false};

extern "C" {
EMSCRIPTEN_KEEPALIVE void WebTest_holdCurrentWorker(TJobThread *jobThread) {
    resumeCreation.store(false, std::memory_order_relaxed);
    reinterpret_cast<JobThread*>(jobThread)->addDetachedTask([] {
        const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
        while (!resumeCreation.load(std::memory_order_acquire)) {
            if (std::chrono::steady_clock::now() >= deadline) std::abort();
            std::this_thread::yield();
        }
    });
}

EMSCRIPTEN_KEEPALIVE void WebTest_releaseHeldWorker() {
    resumeCreation.store(true, std::memory_order_release);
}

EMSCRIPTEN_KEEPALIVE void WebTest_contextWidth(TJobThread *jobThread, filament::Engine* engine, void (*done)(uint32_t)) {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    rt->addDetachedTask([=] {
        int width = 0, height = 0;
        auto context = emscripten_webgl_get_current_context();
        auto result = emscripten_webgl_get_drawing_buffer_size(context, &width, &height);
        const uint32_t value = result == EMSCRIPTEN_RESULT_SUCCESS ? width : 0;
        rt->dispatchCallback([=] { done(value); });
    });
}

EMSCRIPTEN_KEEPALIVE void WebTest_attachScene(TJobThread *jobThread, filament::Engine* engine,
        RenderManager* manager, int slot, uint32_t id, void (*done)(uint32_t)) {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    rt->addDetachedTask([=] {
        auto& s = scenes[slot];
        s.swapChain = engine->createSwapChain(nullptr);
        s.scene = engine->createScene();
        s.view = engine->createView();
        s.camera = utils::EntityManager::get().create();
        s.view->setCamera(engine->createCamera(s.camera));
        s.view->setScene(s.scene);
        s.view->setViewport({0, 0, 32, 32});
        s.view->setPostProcessingEnabled(false);
        manager->setRenderable(s.swapChain, &s.view, 1);
        rt->dispatchCallback([=] { done(id); });
    });
}

EMSCRIPTEN_KEEPALIVE void WebTest_frameId(TJobThread *jobThread, filament::Engine* engine,
        filament::Renderer* renderer, void (*done)(uint32_t)) {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    rt->addDetachedTask([=] {
        uint32_t latest = 0;
        for (const auto& frame : renderer->getFrameInfoHistory()) {
            latest = std::max(latest, frame.frameId);
        }
        rt->dispatchCallback([=] { done(latest); });
    });
}

// Called only after the public RenderManager_destroyJobThread completes.
EMSCRIPTEN_KEEPALIVE void WebTest_destroyScene(TJobThread *jobThread, filament::Engine* engine,
        int slot, uint32_t id, void (*done)(uint32_t)) {
    auto* rt = reinterpret_cast<JobThread*>(jobThread);
    rt->addDetachedTask([=] {
        auto& s = scenes[slot];
        engine->destroy(s.view);
        engine->destroy(s.scene);
        engine->destroyCameraComponent(s.camera);
        utils::EntityManager::get().destroy(s.camera);
        engine->destroy(s.swapChain);
        s = {};
        rt->dispatchCallback([=] { done(id); });
    });
}

EMSCRIPTEN_KEEPALIVE int WebTest_liveWorkers() {
    return JobThread::mLiveWorkerCount.load();
}
}
