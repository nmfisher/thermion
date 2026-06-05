#pragma once

#include <emscripten/html5_webgl.h>

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
void *Thermion_createWebGPUPlatform();


#ifdef __cplusplus
}
#endif

