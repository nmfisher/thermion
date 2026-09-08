#pragma once
#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C" {
#endif
// Allocates a Filament mat4 directly and initializes it to identity.
// The caller owns it and must finish all queued uses before destroying it.
EMSCRIPTEN_KEEPALIVE TNativeMatrix4* NativeMatrix4_create();
// Borrowed column-major storage, valid until destroy.
EMSCRIPTEN_KEEPALIVE double* NativeMatrix4_getData(TNativeMatrix4* matrix);
EMSCRIPTEN_KEEPALIVE void NativeMatrix4_destroy(TNativeMatrix4* matrix);
#ifdef __cplusplus
}
#endif
