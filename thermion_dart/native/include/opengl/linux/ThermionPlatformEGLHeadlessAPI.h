#pragma once

#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* ThermionPlatformEGLHeadlessHandle;

// Create an OpenGLPlatform backed by the given EGL display.
// The returned handle is a pointer to a filament::backend::OpenGLPlatform and
// can be passed directly to Engine::create() as the platform parameter.
ThermionPlatformEGLHeadlessHandle ThermionPlatformEGLHeadless_Create(void* eglDisplay);
void ThermionPlatformEGLHeadless_Destroy(ThermionPlatformEGLHeadlessHandle handle);

#ifdef __cplusplus
}
#endif
