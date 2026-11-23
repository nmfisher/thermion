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

// Hands the GPUDevice used by Filament's WebGPU backend to JavaScript.
//
// The browser creates the device (Module['preinitializedWebGPUDevice'], see
// webgpu_device.js) and the Emscripten WebGPU runtime imports it as a
// WGPUDevice handle. This exports that handle back to JavaScript the same
// way the runtime resolves every wgpu* call (WebGPU.getJsObject): the
// GPUDevice object is stored on Module['thermionWebGPUDevice'] so another
// module (e.g. a ray-tracing sidecar renderer) can import it with
// WebGPU.importJsDevice and share GPU resources with Thermion.
//
// Returns the raw WGPUDevice handle, or 0 when there is no WebGPU device:
// a WebGL2 build, or no engine created with Backend.WEBGPU yet.
uint32_t Thermion_exportWebGPUDevice(void);

#ifdef __cplusplus
}
#endif
