#include "ThermionWebApi.h"
#include "rendering/WebJobThread.hpp"

#include <backend/platforms/WebGPUPlatformWasm.h>
#include <emscripten/emscripten.h>

#include <iostream>
#include <string>

namespace {

class ThermionWebGPUPlatform : public filament::backend::WebGPUPlatformWasm {
public:
    explicit ThermionWebGPUPlatform(const char* canvasSelector)
        : _canvasSelector(canvasSelector) {}

    wgpu::Extent2D getSurfaceExtent(void* /*nativeWindow*/) const override {
        return WebGPUPlatformWasm::getSurfaceExtent(const_cast<char*>(_canvasSelector.c_str()));
    }

    wgpu::Surface createSurface(void* /*nativeWindow*/, uint64_t flags) override {
        return WebGPUPlatformWasm::createSurface(_canvasSelector.data(), flags);
    }

private:
    std::string _canvasSelector;
};

} // namespace

extern "C" EMSCRIPTEN_KEEPALIVE void* Thermion_createWebGPUPlatform() {
    if (!EM_ASM_INT({ return Boolean(Module['preinitializedWebGPUDevice']); })) {
        std::cerr << "WebGPU requires a browser GPU adapter and device" << std::endl;
        return nullptr;
    }

    // Use the same canvas as the viewer's job thread.
    const char* canvasSelector = thermion::WebJobThread::currentCanvasSelector();
    return static_cast<filament::backend::Platform*>(
        new ThermionWebGPUPlatform(canvasSelector ? canvasSelector : "#thermion_canvas"));
}
