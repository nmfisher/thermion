#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Material package format version expected by the linked Filament build.
/// This is distinct from the Filament release version.
EMSCRIPTEN_KEEPALIVE uint32_t Material_getSupportedVersion();

/// Reads the material format version, or returns -1 for an invalid chunk layout
/// or a missing, duplicate, or incorrectly sized MAT_VERS chunk.
/// Checks chunk boundaries without parsing their payloads. A nonnegative result
/// does not establish that the package is complete or valid for a given backend.
/// Reads synchronously and does not retain data. No engine is required.
EMSCRIPTEN_KEEPALIVE int64_t Material_getPackageVersion(const uint8_t *data, size_t length);

#ifdef __cplusplus
}
#endif
