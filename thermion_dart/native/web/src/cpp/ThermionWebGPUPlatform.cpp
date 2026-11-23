#include "ThermionWebApi.h"
#include "rendering/WebJobThread.hpp"

#include <backend/platforms/WebGPUPlatformWasm.h>
#include <emscripten/emscripten.h>

#include <cstdint>
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

extern "C" EMSCRIPTEN_KEEPALIVE uint32_t Thermion_exportWebGPUDevice() {
    // The platform imports the browser's GPUDevice (webgpu_device.js ->
    // Module['preinitializedWebGPUDevice']) as a WGPUDevice handle when the
    // engine is created; that handle lives for the engine's lifetime.
    wgpu::Device device = filament::backend::WebGPUPlatformWasm::sDevice;
    if (!device) {
        return 0;
    }

    // Emscripten's WebGPU runtime (library_webgpu.js) keeps the JS object for
    // every WGPU* handle in its object table; getJsObject is its public
    // handle -> JS translation. EM_ASM runs inside the module's JS scope, so
    // the runtime's WebGPU object and Module are both in reach: hand the
    // GPUDevice to JavaScript via Module, where a sidecar can import it
    // (WebGPU.importJsDevice) to share the device with Thermion.
    const uint32_t handle = static_cast<uint32_t>(reinterpret_cast<uintptr_t>(device.Get()));
    EM_ASM({
        Module['thermionWebGPUDevice'] = WebGPU.getJsObject($0);
    }, handle);
    return handle;
}
