#pragma once

#include <emscripten/emscripten.h>
#include <emscripten/html5_webgl.h>

#ifdef __cplusplus
extern "C" {
#endif

EMSCRIPTEN_WEBGL_CONTEXT_HANDLE Thermion_createGLContext();


#ifdef __cplusplus
}
#endif

