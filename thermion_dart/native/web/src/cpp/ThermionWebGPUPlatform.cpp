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

    wgpu::Surface createSurface(void* nativeWindow, uint64_t flags) override {
        // The Wasm platform takes the canvas selector through the void*
        // nativeWindow parameter (same cast as getSurfaceExtent). The general
        // Engine_createSwapChain path passes no window on web, so the surface
        // is the viewer canvas this platform was created with; an offscreen
        // swapchain (Thermion_createOffscreenSwapChain) passes its hidden
        // canvas selector instead, so nothing is presented. Either way flags
        // are pure filament::backend::SWAP_CHAIN_CONFIG_* values and reach
        // Filament untouched.
        const char* selector = nativeWindow
            ? static_cast<const char*>(nativeWindow)
            : _canvasSelector.c_str();
        return WebGPUPlatformWasm::createSurface(const_cast<char*>(selector), flags);
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
