#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

typedef struct TGltfMeshData {
    float* vertices;
    uint32_t vertexCount;
    uint32_t* indices;
    uint32_t indexCount;
    TPrimitiveType primitiveType;
} TGltfMeshData;

void dummy(TGltfMeshData dummy);

// Parse glTF and extract all mesh geometry data
// Returns 0 on success, non-zero on failure
EMSCRIPTEN_KEEPALIVE int GltfParser_parseBuffer(
    const uint8_t* data,
    size_t length,
    const char* meshName,
    TGltfMeshData* outMeshData
);

// Free parsed data
EMSCRIPTEN_KEEPALIVE void GltfParser_freeMeshData(TGltfMeshData* meshData);

#ifdef __cplusplus
}
#endif
