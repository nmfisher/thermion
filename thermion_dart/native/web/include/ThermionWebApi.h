#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include <emscripten/emscripten.h>
#include <emscripten/html5_webgl.h>

#ifdef __cplusplus
extern "C" {
#endif

EMSCRIPTEN_WEBGL_CONTEXT_HANDLE EMSCRIPTEN_KEEPALIVE Thermion_createGLContext();

#ifdef __cplusplus
}
#endif

