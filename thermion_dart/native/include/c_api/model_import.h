#pragma once

#include "APIExport.h"
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

// Opaque handle to a model importer (Assimp-backed; supports OBJ, FBX, glTF, STL, PLY, ...)
typedef struct TModelImporter TModelImporter;

// Returns true iff Assimp model loading was compiled into this build
// (i.e. THERMION_ASSIMP was defined at compile time). Always available;
// the rest of this API is only present when this returns true.
EMSCRIPTEN_KEEPALIVE bool ModelImporter_isSupported();

// Load a model from a byte buffer, returns an opaque handle to the importer.
//
// [extensionHint] is the file extension *without* the dot (e.g. "obj", "fbx",
// "glb", "stl", "ply"). Assimp uses it to select the right importer when
// reading from memory. Pass nullptr or "" to default to "obj".
//
// Returns nullptr on failure.
EMSCRIPTEN_KEEPALIVE TModelImporter* ModelImporter_loadFromBuffer(const uint8_t* data, size_t size,
                                                              const char* extensionHint);

// Get mesh count
EMSCRIPTEN_KEEPALIVE int ModelImporter_getMeshCount(TModelImporter* importer);

// Get vertex data for a mesh
// Returns pointer to float array and count (3 floats per vertex)
EMSCRIPTEN_KEEPALIVE void ModelImporter_getVertices(TModelImporter* importer, int meshIndex,
                                                   float** outVertices, int* outCount);

// Get index data for a mesh
// Returns pointer to uint32_t array and count
EMSCRIPTEN_KEEPALIVE void ModelImporter_getIndices(TModelImporter* importer, int meshIndex,
                                                  uint32_t** outIndices, int* outCount);

// Get normal data for a mesh
// Returns pointer to float array and count (3 floats per normal)
// Returns nullptr if mesh has no normals
EMSCRIPTEN_KEEPALIVE void ModelImporter_getNormals(TModelImporter* importer, int meshIndex,
                                                  float** outNormals, int* outCount);

// Get UV data for a mesh
// Returns pointer to float array and count (2 floats per UV)
// Returns nullptr if mesh has no UVs
EMSCRIPTEN_KEEPALIVE void ModelImporter_getUVs(TModelImporter* importer, int meshIndex,
                                              float** outUVs, int* outCount);

// Get material name for a mesh
// Returns nullptr if mesh has no material
EMSCRIPTEN_KEEPALIVE const char* ModelImporter_getMaterialName(TModelImporter* importer, int meshIndex);

// Get mesh name (from o/g directive)
// Returns nullptr if mesh has no name
EMSCRIPTEN_KEEPALIVE const char* ModelImporter_getMeshName(TModelImporter* importer, int meshIndex);

// Free the importer and all associated resources
EMSCRIPTEN_KEEPALIVE void ModelImporter_destroy(TModelImporter* importer);

#ifdef __cplusplus
}
#endif
