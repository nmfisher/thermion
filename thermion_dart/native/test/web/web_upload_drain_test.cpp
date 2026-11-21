#include "rendering/RenderManager.hpp"

#include <filament/Texture.h>
#include <cstdio>
#include <cstdlib>

// This test has no animations or plugins. Keep the real RenderManager and
// Filament command queues, using Filament's NOOP backend instead of a GPU.
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
    uint8_t pixels[4] = {17, 43, 91, 255};
    int released = 0;
    for (bool paused : {true, false}) {
        manager.setPaused(paused);
        const int previous = released;
        for (int i = 0; i < 64; ++i) {
            Texture::PixelBufferDescriptor descriptor(pixels, sizeof(pixels),
                Texture::Format::RGBA, Texture::Type::UBYTE,
                [](void*, size_t, void* user) { ++*static_cast<int*>(user); }, &released);
            texture->setImage(*engine, 0, std::move(descriptor));
        }
        check(released == previous, "uploads stay pending before the command drain");
        check(!manager.tick(0), "upload drain must not submit a visible frame");
        check(released == previous + 64, "tick delivers every upload-release callback without rendering");
    }
    engine->destroy(texture);
    engine->destroy(renderer);
    Engine::destroy(&engine);
    std::puts("PASS: 128 real Filament uploads released while paused or without attached views");
}
