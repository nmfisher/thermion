#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

// obviously __EMSCRIPTEN__ should always be true when 
// compiling this 
// just to satisfy code-gen
#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#include <emscripten/html5_webgl.h>
#endif 

// when re-generating JS interop bindings, 
// we may not know exactly where the emscripten headers
// are, so we define this manually just to ensure codegen works.
#ifndef EMSCRIPTEN_WEBGL_CONTEXT_HANDLE
typedef uintptr_t EMSCRIPTEN_WEBGL_CONTEXT_HANDLE;
#endif

#ifdef __cplusplus
extern "C" {
#endif

EMSCRIPTEN_WEBGL_CONTEXT_HANDLE Thermion_createGLContext(
    // bool alpha,
    // bool depth,
    // bool stencil,
    // bool antiAlias,
    // bool explicitSwapControl,
    // bool preserveDrawingBuffer,
    // int proxyMode,
    // bool renderViaOffscreenBackBuffer
);

#ifdef __cplusplus
}
#endif

