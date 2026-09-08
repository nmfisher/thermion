#pragma once
#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C" {
#endif
// Allocates a Filament mat4 directly and initializes it to identity; null on failure.
// The caller owns it and must finish all queued uses before destroying it.
EMSCRIPTEN_KEEPALIVE TMat4* Mat4_create();
// Borrowed column-major storage, valid until destroy.
EMSCRIPTEN_KEEPALIVE double* Mat4_getData(TMat4* matrix);
EMSCRIPTEN_KEEPALIVE void Mat4_destroy(TMat4* matrix);
#ifdef __cplusplus
}
#endif
