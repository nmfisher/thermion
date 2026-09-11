// Browser integration helpers for the real RenderManager / Filament pipeline.
// Compiled only when web_frame_fixture.cmake is explicitly supplied to CMake.
#include "rendering/RenderThread.hpp"
#include "rendering/RenderManager.hpp"
#include <filament/Engine.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/View.h>
#include <utils/EntityManager.h>
#include <algorithm>
#include <emscripten.h>

using namespace thermion;
// The production dispatcher resolves each engine to its owning worker.
extern "C" RenderThread* RT(void* owner);

struct TestScene {
    filament::SwapChain* swapChain = nullptr;
    filament::View* view = nullptr;
    filament::Scene* scene = nullptr;
    utils::Entity camera;
};
// Each slot is accessed only on its owning worker.
static TestScene scenes[2];

extern "C" {
EMSCRIPTEN_KEEPALIVE void WebTest_attachScene(filament::Engine* engine,
        RenderManager* manager, int slot, uint32_t id, void (*done)(uint32_t)) {
    auto* rt = RT(engine);
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

EMSCRIPTEN_KEEPALIVE void WebTest_frameId(filament::Engine* engine,
        filament::Renderer* renderer, void (*done)(uint32_t)) {
    auto* rt = RT(engine);
    rt->addDetachedTask([=] {
        uint32_t latest = 0;
        for (const auto& frame : renderer->getFrameInfoHistory()) {
            latest = std::max(latest, frame.frameId);
        }
        rt->dispatchCallback([=] { done(latest); });
    });
}

// Called only after the public RenderManager_destroyRenderThread completes.
EMSCRIPTEN_KEEPALIVE void WebTest_destroyScene(filament::Engine* engine,
        int slot, uint32_t id, void (*done)(uint32_t)) {
    auto* rt = RT(engine);
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
    return RenderThread::mLiveWorkerCount.load();
}
}
