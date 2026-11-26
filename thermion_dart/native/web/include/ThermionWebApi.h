#pragma once

#include "c_api/APIBoundaryTypes.h"
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

// Creates an offscreen swapchain on [tEngine]: every frame is rendered into
// the hidden canvas reported by Thermion_getOffscreenCanvasSelector instead
// of the viewer's canvas, so nothing is ever presented to the user.
// JavaScript composites the frame itself: draw the hidden canvas (e.g.
// drawImage), or copy its WebGPU context's current texture
// (context.getCurrentTexture()) into a texture you own with
// copyTextureToTexture / copyExternalImageToTexture. Do NOT bind
// getCurrentTexture() directly as a sampled texture: canvas surfaces only
// carry RENDER_ATTACHMENT (+ COPY_SRC for READABLE swapchains), never
// TEXTURE_BINDING, so sampling them fails WebGPU validation.
//
// Offscreen-ness is carried by this entry point alone: [flags] is handed to
// Filament unmodified and must be a pure OR of
// filament::backend::SWAP_CHAIN_CONFIG_* values (the TSWAP_CHAIN_CONFIG_*
// exports mirror them 1:1; Thermion defines no swapchain flag of its own).
// The usual choice is TSWAP_CHAIN_CONFIG_TRANSPARENT |
// TSWAP_CHAIN_CONFIG_READABLE, plus TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER
// when requested. Headless swapchains (Engine_createHeadlessSwapChain)
// never need this: they create no canvas surface, so there is no present
// step to skip.
//
// Returns nullptr when the page has no document/body to host the hidden
// canvas (e.g. a worker), or when [tEngine] is null.
//
// Must run as a job on [tEngine]'s job thread: the viewer canvas (and so
// its hidden canvas) is resolved from the job thread's selector exactly like
// Thermion_createWebGPUPlatform, also in multi-viewer apps with one engine
// per canvas. Use Thermion_createOffscreenSwapChainJobThread.
TSwapChain *Thermion_createOffscreenSwapChain(TEngine *tEngine, uint64_t flags);

// Runs Thermion_createOffscreenSwapChain as a job on [jobThread] (the same
// dispatch Engine_createSwapChainJobThread uses) and reports the TSwapChain,
// or nullptr, to [onComplete] on the thread that created the job thread.
void Thermion_createOffscreenSwapChainJobThread(TJobThread *jobThread, TEngine *tEngine, uint64_t flags, void (*onComplete)(TSwapChain *));
#endif

// ---------------------------------------------------------------------------
// Offscreen swapchains and WebGPU device export.
//
// Both features are web-only. They exist so a JavaScript-side compositor
// (e.g. a ray-tracing sidecar) can drive the final image: Thermion renders
// into a canvas that is never presented, and shares the GPUDevice the
// WebGPU backend runs on.
// ---------------------------------------------------------------------------

// Selector ("#id") of the hidden canvas that receives the frames of the
// offscreen swapchains (Thermion_createOffscreenSwapChain) belonging to
// [jobThread]'s engine. The viewer canvas is resolved from the selector the
// job thread was created with (JobThread_createForCanvas;
// "#thermion_canvas" when none was given), so this always matches the
// canvas those swapchains render into — also in multi-viewer apps with one
// engine per canvas. The hidden canvas is created on first use and kept for
// the lifetime of the page so it can be reused by later swapchains; it is
// sized by Filament to match the viewer canvas and is never visible.
// Returns nullptr when the page has no document/body (e.g. a worker).
const char *Thermion_getOffscreenCanvasSelector(TJobThread *jobThread);

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
