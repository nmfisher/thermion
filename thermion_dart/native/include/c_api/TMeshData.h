#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

// Shared flat-mesh transfer struct, used by every model-file parser at the
// FFI boundary (the Assimp-backed ModelImporter and the cgltf-backed
// GltfParser). One FFI crossing per mesh instead of one per attribute.
//
// Ownership: the native side mallocs the buffers and the strings; the caller
// releases everything with MeshData_dispose. Fields not produced by a parser
// are null/0 (e.g. the cgltf path fills vertices/indices only).
typedef struct TMeshData {
    // Mesh/object name (may be null)
    char* name;
    // Material name (may be null)
    char* materialName;
    // Vertex positions, 3 floats per vertex (x, y, z)
    float* vertices;
    int vertexCount;
    // Vertex normals, 3 floats per normal (may be null/0)
    float* normals;
    int normalCount;
    // First UV channel, 2 floats per UV (may be null/0)
    float* uvs;
    int uvCount;
    // Triangle indices
    uint32_t* indices;
    int indexCount;
    // Primitive type of the mesh (parsers that always triangulate report
    // PRIMITIVETYPE_TRIANGLES)
    TPrimitiveType primitiveType;
} TMeshData;

// Frees the buffers and strings held by a TMeshData and zeroes the struct.
// Safe to call on a zero-initialised struct.
EMSCRIPTEN_KEEPALIVE void MeshData_dispose(TMeshData* meshData);

#ifdef __cplusplus
}
#endif
