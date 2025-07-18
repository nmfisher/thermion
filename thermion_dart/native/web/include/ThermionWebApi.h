#pragma once

#include <emscripten/html5_webgl.h>

#ifdef __cplusplus
extern "C" {
#endif

void Thermion_resizeCanvas(int width, int height);
EMSCRIPTEN_WEBGL_CONTEXT_HANDLE Thermion_createGLContext();
EMSCRIPTEN_WEBGL_CONTEXT_HANDLE Thermion_getGLContext();


#ifdef __cplusplus
}
#endif

