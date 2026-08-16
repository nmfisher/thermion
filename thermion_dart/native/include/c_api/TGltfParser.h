#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

// Flat-mesh transfer struct used by the cgltf-backed glTF parser at the FFI
// boundary. One FFI crossing per mesh instead of one per attribute.
//
// Ownership: the native side mallocs the buffers and the strings; the caller
// releases everything with MeshData_dispose. Fields not produced by the
// parser are null/0 (this parser fills name/vertices/indices/primitiveType
// only).
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
