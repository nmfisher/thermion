#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include <emscripten/emscripten.h>
#include <emscripten/html5_webgl.h>

// when re-generating JS interop bindings, 
// we may not know exactly where the emscripten headers
// are, so we define this manually just to ensure codegen works.
#ifndef EMSCRIPTEN_WEBGL_CONTEXT_HANDLE
typedef uintptr_t EMSCRIPTEN_WEBGL_CONTEXT_HANDLE;
#endif

#ifdef __cplusplus
extern "C" {
#endif

EMSCRIPTEN_WEBGL_CONTEXT_HANDLE EMSCRIPTEN_KEEPALIVE Thermion_createGLContext();

#ifdef __cplusplus
}
#endif

