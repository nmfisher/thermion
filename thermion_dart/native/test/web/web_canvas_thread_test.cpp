#include "rendering/RenderThread.hpp"
#include "rendering/RenderManager.hpp"

#include <filament/Texture.h>
#include <cstdio>
#include <cstdlib>

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
    {
        // There is no DOM/canvas in Node. This also proves that construction
        // neither transfers a canvas nor starts Thermion's render pthread.
        thermion::RenderThread thread("#canvas-that-does-not-exist");
        check(!thread.creationFailed(), "main-thread construction succeeds without a DOM");
        check(thermion::RenderThread::mLiveWorkerCount.load() == 0, "no render worker starts");
        thread.setRenderManager(&manager);
        const auto caller = std::this_thread::get_id();
        std::packaged_task<int()> task([&] {
            check(std::this_thread::get_id() == caller, "task executes on the calling thread");
            return 42;
        });
        auto result = thread.addTask(task);
        check(result.wait_for(std::chrono::seconds(0)) == std::future_status::ready,
              "packaged result is ready before dispatch returns");
        check(result.get() == 42, "packaged result is preserved");
        int sequence = 0;
        thread.addDetachedTask([&] {
            check(sequence++ == 0, "outer command executes first");
            thread.addDetachedTask([&] { check(sequence++ == 1, "nested command executes in order"); });
        });
        check(sequence == 2, "detached commands finish synchronously");
        uint8_t pixels[4] = {17, 43, 91, 255};
        int released = 0;
        thread.addDetachedTask([&] {
            Texture::PixelBufferDescriptor descriptor(pixels, sizeof(pixels),
                Texture::Format::RGBA, Texture::Type::UBYTE,
                [](void*, size_t, void* user) { ++*static_cast<int*>(user); }, &released);
            texture->setImage(*engine, 0, std::move(descriptor));
        });
        check(released == 1, "dispatch drains the real upload without drawing or a later rAF");
    }
    check(thermion::RenderThread::mLiveWorkerCount.load() == 0, "teardown has no render pthread to join");
    engine->destroy(texture);
    engine->destroy(renderer);
    Engine::destroy(&engine);
    std::puts("PASS: main-thread dispatch, nested commands, upload release and teardown");
}
