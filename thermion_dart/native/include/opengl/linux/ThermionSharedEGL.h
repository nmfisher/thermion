#pragma once

#include <stdint.h>

// When the Flutter plugin obtains an EGL context from GdkGLContext, it must
// also pass the EGL display to Filament so that PlatformEGL creates its
// shared context on the SAME display. We pack both into this struct and
// pass the struct pointer as Engine::create()'s sharedContext parameter.
//
// PlatformEGL (patched by build_linux.sh) checks the magic field to
// distinguish this struct from a raw EGLContext pointer.

#define THERMION_SHARED_EGL_MAGIC 0x5448524D45474CUL // "THRMEGL"

struct ThermionSharedEGL {
    uint64_t magic;   // must be THERMION_SHARED_EGL_MAGIC
    void*    display; // EGLDisplay
    void*    context; // EGLContext
};
