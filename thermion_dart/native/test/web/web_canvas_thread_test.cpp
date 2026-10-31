#include "rendering/JobThread.hpp"
#include "rendering/RenderManager.hpp"

#include <filament/Texture.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <thread>

namespace thermion {
void AnimationManager::update(uint64_t) {}
namespace plugin { void UpdatePlugins(uint64_t) {} }
}

static void check(bool value, const char* message) {
    if (!value) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        std::abort();
    }
}

static void checkCanvas(const char* expected, const char* message) {
    const char* actual = thermion::JobThread::currentCanvasSelector();
    check(actual && std::strcmp(actual, expected) == 0, message);
}

int main() {
    using namespace filament;
    Engine::Config config;
    config.jobSystemThreadCount = 1;
    auto* engine = Engine::create(Engine::Backend::NOOP, nullptr, nullptr, &config);
    check(engine != nullptr, "NOOP engine creation");
    auto* renderer = engine->createRenderer();
    auto* texture = Texture::Builder().width(1).height(1).levels(1)
        .sampler(Texture::Sampler::SAMPLER_2D)
        .format(Texture::InternalFormat::RGBA8)
        .usage(Texture::Usage::SAMPLEABLE | Texture::Usage::UPLOADABLE)
        .build(*engine);
    thermion::RenderManager manager(engine, renderer);
    manager.setPaused(true);
    check(thermion::JobThread::currentCanvasSelector() == nullptr, "no job is bound initially");
    {
        // There is no DOM/canvas in Node. This also proves that construction
        // neither transfers a canvas nor starts Thermion's render pthread.
        auto owner = thermion::JobThread::create("#canvas-that-does-not-exist");
        check(owner != nullptr, "main-thread construction succeeds without a DOM");
        auto& thread = *owner;
        check(thermion::JobThread::currentCanvasSelector() == nullptr, "construction does not bind a job");
        thermion::JobThreadBase& queue = thread;
        check(!queue.isStopping(), "base dispatch reads the platform stop state");
        check(thermion::JobThread::mLiveWorkerCount.load() == 0, "no render worker starts");
        thread.setRenderManager(&manager);
        const auto caller = std::this_thread::get_id();
        std::packaged_task<int()> task([&] {
            check(std::this_thread::get_id() == caller, "task executes on the calling thread");
            checkCanvas("#canvas-that-does-not-exist", "job uses its own canvas selector");
            return 42;
        });
        auto result = queue.addTask(task);
        check(result.wait_for(std::chrono::seconds(0)) == std::future_status::ready,
              "packaged result is ready before dispatch returns");
        check(result.get() == 42, "packaged result is preserved");
        check(thermion::JobThread::currentCanvasSelector() == nullptr, "job binding is cleared");
        auto other = thermion::JobThread::create("#other-canvas");
        queue.addDetachedTask([&] {
            other->addDetachedTask([] {
                checkCanvas("#other-canvas",
                      "nested job uses the other queue's selector");
            });
            checkCanvas("#canvas-that-does-not-exist", "nested job restores the caller's selector");
            thermion::JobThread::destroy(std::move(other));
            checkCanvas("#canvas-that-does-not-exist", "destruction restores the caller's selector");
        });
        check(thermion::JobThread::currentCanvasSelector() == nullptr, "outer job restores no binding");
        int sequence = 0;
        queue.addDetachedTask([&] {
            check(sequence++ == 0, "outer command executes first");
            queue.addDetachedTask([&] { check(sequence++ == 1, "nested command executes in order"); });
        });
        check(sequence == 2, "detached commands finish synchronously");
        uint8_t pixels[4] = {17, 43, 91, 255};
        int released = 0;
        queue.addDetachedTask([&] {
            Texture::PixelBufferDescriptor descriptor(pixels, sizeof(pixels),
                Texture::Format::RGBA, Texture::Type::UBYTE,
                [](void*, size_t, void* user) {
                    checkCanvas("#canvas-that-does-not-exist", "upload release keeps the job binding");
                    ++*static_cast<int*>(user);
                }, &released);
            texture->setImage(*engine, 0, std::move(descriptor));
        });
        check(released == 1, "dispatch drains the real upload without drawing or a later rAF");
        thermion::JobThread::destroy(std::move(owner));
        check(!owner, "destruction consumes ownership");
        check(thermion::JobThread::currentCanvasSelector() == nullptr, "destruction clears its binding");
    }
    check(thermion::JobThread::mLiveWorkerCount.load() == 0, "teardown has no render pthread to join");
    engine->destroy(texture);
    engine->destroy(renderer);
    Engine::destroy(&engine);
    std::puts("PASS: main-thread dispatch, nested commands, upload release and teardown");
}
