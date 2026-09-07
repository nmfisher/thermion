#pragma once
#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C" {
#endif
// Creates an identity matrix. The caller owns the handle and must destroy it.
EMSCRIPTEN_KEEPALIVE TNativeMatrix4* NativeMatrix4_create();
// Borrowed column-major storage; valid until destroy (or the last queued owner).
EMSCRIPTEN_KEEPALIVE double* NativeMatrix4_getData(TNativeMatrix4* matrix);
EMSCRIPTEN_KEEPALIVE void NativeMatrix4_destroy(TNativeMatrix4* matrix);
#ifdef __cplusplus
}
#endif
