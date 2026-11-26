#include "ThermionWebApi.h"
#include "WebGLContext.hpp"
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
        // Always the viewer canvas' size, also for offscreen swapchains, so
        // the hidden canvas tracks what the viewer would have shown.
        return WebGPUPlatformWasm::getSurfaceExtent(const_cast<char*>(_canvasSelector.c_str()));
    }

    wgpu::Surface createSurface(void* /*nativeWindow*/, uint64_t flags) override {
        const char* selector = _canvasSelector.c_str();
        if (flags & THERMION_SWAP_CHAIN_CONFIG_SKIP_PRESENT) {
            // Offscreen swapchain: surface on the hidden canvas instead of the
            // viewer's, so nothing is presented and JavaScript composites the
            // rendered texture itself (see ThermionWebApi.h).
            const char* offscreen = thermion::offscreenCanvasSelectorFor(selector);
            if (offscreen) {
                selector = offscreen;
            } else {
                std::cerr << "Offscreen swapchain requested but no document is available; "
                             "presenting to the viewer canvas instead" << std::endl;
            }
        }
        // Same cast as getSurfaceExtent: the Wasm platform takes the canvas
        // selector through the void* nativeWindow parameter. Strip our own
        // flag bit so it never leaks into Filament's swapchain-config layer.
        return WebGPUPlatformWasm::createSurface(
            const_cast<char*>(selector), flags & ~THERMION_SWAP_CHAIN_CONFIG_SKIP_PRESENT);
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
    // EM_ASM passes integer args as SIGNED 32-bit values, and with the
    // emdawnwebgpu port device.Get() is a heap pointer: handles >= 0x80000000
    // arrive negative and getJsObject(negative) returns undefined. >>> 0
    // restores the unsigned pointer before the table lookup.
    EM_ASM({
        Module['thermionWebGPUDevice'] = WebGPU.getJsObject($0 >>> 0);
    }, handle);
    return handle;
}
