#pragma once

#include "APIExport.h"
#include "TMeshData.h"

#ifdef __cplusplus
extern "C"
{
#endif

// Parse glTF and extract the flat mesh geometry data of the first matching
// mesh (all meshes when [meshName] is null) into the shared TMeshData
// out-struct. Positions and indices only; normals/UVs/names stay null.
// Returns 0 on success, non-zero on failure.
//
// The caller releases the copied buffers with MeshData_dispose.
EMSCRIPTEN_KEEPALIVE int GltfParser_parseBuffer(
    const uint8_t* data,
    size_t length,
    const char* meshName,
    TMeshData* outMeshData
);

#ifdef __cplusplus
}
#endif
