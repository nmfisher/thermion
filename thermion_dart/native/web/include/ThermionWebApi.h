#pragma once

#include <emscripten/html5_webgl.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void Thermion_setCanvasElementSize(const char *name, int width, int height);
void Thermion_destroyCanvas(const char *canvasSelector);
// Creates a WebGL2 context on the given canvas element (e.g.
// "#thermion_canvas_0"). Called from Engine_create on the engine's render
// thread; the canvas must have been transferred to that thread.
EMSCRIPTEN_WEBGL_CONTEXT_HANDLE Thermion_createGLContext(const char *canvasSelector);
EMSCRIPTEN_WEBGL_CONTEXT_HANDLE Thermion_getGLContext();

// Returns a heap-allocated filament::backend::WebGPUPlatform subclass cast to void*.
// Ownership transfers to Engine::create, which destroys it when the engine shuts down.
// Only defined when the engine was built with THERMION_SUPPORTS_WEBGPU
// (-DTHERMION_ENABLE_WEBGPU=ON for the web build).
#if defined(THERMION_SUPPORTS_WEBGPU)
void *Thermion_createWebGPUPlatform();
#endif

// ---------------------------------------------------------------------------
// Offscreen (present-skip) swapchains and WebGPU device export.
//
// Both features are web-only. They exist so a JavaScript-side compositor
// (e.g. a ray-tracing sidecar) can drive the final image: Thermion renders
// into a texture that is never presented, and shares the GPUDevice the
// WebGPU backend runs on.
// ---------------------------------------------------------------------------

// Thermion-owned swapchain flag, OR-ed into the `flags` argument of
// Engine_createSwapChain. It has no effect on Engine_createHeadlessSwapChain:
// headless swapchains never create a canvas surface
// (ThermionWebGPUPlatform::createSurface is not involved), so there is no
// present step to skip.
//
// When set, the swapchain is offscreen: every frame is rendered into the
// hidden canvas returned by Thermion_getOffscreenCanvasSelector instead of
// the viewer's canvas, so nothing is ever presented to the user. JavaScript
// composites the frame itself: draw the hidden canvas (e.g. drawImage), or
// copy its WebGPU context's current texture (context.getCurrentTexture())
// into a texture you own with copyTextureToTexture /
// copyExternalImageToTexture. Do NOT bind getCurrentTexture() directly as a
// sampled texture: canvas surfaces only carry RENDER_ATTACHMENT (+ COPY_SRC
// for READABLE swapchains), never TEXTURE_BINDING, so sampling them fails
// WebGPU validation.
//
// Only the WebGPU backend honours the flag (build with
// -DTHERMION_ENABLE_WEBGPU=ON); other backends ignore it and present as usual.
// The platform strips the bit before handing flags to Filament, so it never
// reaches Filament's own swapchain-config layer.
// The bit sits above every filament::backend::SWAP_CHAIN_CONFIG_* flag so it
// never changes meaning for Filament. TSWAP_CHAIN_CONFIG_SKIP_PRESENT exports
// the same value for bindings, like the TSWAP_CHAIN_CONFIG_* variables.
#define THERMION_SWAP_CHAIN_CONFIG_SKIP_PRESENT ((uint64_t)1 << 62)
extern uint64_t TSWAP_CHAIN_CONFIG_SKIP_PRESENT;

// Selector ("#id") of the hidden canvas that receives the frames of the
// SKIP_PRESENT swapchain created for the canvas [canvasSelector] (e.g.
// "#thermion_canvas_0"). The canvas is created on first use and kept for the
// lifetime of the page so it can be reused by later swapchains; it is sized
// by Filament to match [canvasSelector] and is never visible.
// Returns nullptr when the page has no document/body (e.g. a worker).
const char *Thermion_getOffscreenCanvasSelector(const char *canvasSelector);

// Hands the GPUDevice used by Filament's WebGPU backend to JavaScript.
//
// The browser creates the device (Module['preinitializedWebGPUDevice'], see
// webgpu_device.js) and the Emscripten WebGPU runtime imports it as a
// WGPUDevice handle. This exports that handle back to JavaScript the same
// way the runtime resolves every wgpu* call (WebGPU.getJsObject): the
// GPUDevice object is stored on Module['thermionWebGPUDevice'] so another
// module (e.g. a sidecar renderer) can import it with WebGPU.importJsDevice
// and share GPU resources with Thermion.
//
// Returns the raw WGPUDevice handle, or 0 when there is no WebGPU device:
// a WebGL2 build, or no engine created with Backend.WEBGPU yet.
uint32_t Thermion_exportWebGPUDevice(void);

#ifdef __cplusplus
}
#endif
