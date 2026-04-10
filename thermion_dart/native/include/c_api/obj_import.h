#pragma once

#include "APIExport.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

// Opaque handle to an OBJ importer
typedef struct TObjImporter TObjImporter;

// Load OBJ from buffer, returns opaque handle to importer
// Returns nullptr on failure
EMSCRIPTEN_KEEPALIVE TObjImporter* ObjImporter_loadFromBuffer(const uint8_t* data, size_t size);

// Get mesh count
EMSCRIPTEN_KEEPALIVE int ObjImporter_getMeshCount(TObjImporter* importer);

// Get vertex data for a mesh
// Returns pointer to float array and count (3 floats per vertex)
EMSCRIPTEN_KEEPALIVE void ObjImporter_getVertices(TObjImporter* importer, int meshIndex,
                                                   float** outVertices, int* outCount);

// Get index data for a mesh
// Returns pointer to uint32_t array and count
EMSCRIPTEN_KEEPALIVE void ObjImporter_getIndices(TObjImporter* importer, int meshIndex,
                                                  uint32_t** outIndices, int* outCount);

// Get normal data for a mesh
// Returns pointer to float array and count (3 floats per normal)
// Returns nullptr if mesh has no normals
EMSCRIPTEN_KEEPALIVE void ObjImporter_getNormals(TObjImporter* importer, int meshIndex,
                                                  float** outNormals, int* outCount);

// Get UV data for a mesh
// Returns pointer to float array and count (2 floats per UV)
// Returns nullptr if mesh has no UVs
EMSCRIPTEN_KEEPALIVE void ObjImporter_getUVs(TObjImporter* importer, int meshIndex,
                                              float** outUVs, int* outCount);

// Get material name for a mesh
// Returns nullptr if mesh has no material
EMSCRIPTEN_KEEPALIVE const char* ObjImporter_getMaterialName(TObjImporter* importer, int meshIndex);

// Get mesh name (from o/g directive)
// Returns nullptr if mesh has no name
EMSCRIPTEN_KEEPALIVE const char* ObjImporter_getMeshName(TObjImporter* importer, int meshIndex);

// Free the importer and all associated resources
EMSCRIPTEN_KEEPALIVE void ObjImporter_destroy(TObjImporter* importer);

#ifdef __cplusplus
}
#endif
