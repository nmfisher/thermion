#pragma once

#include "APIExport.h"
#include "TMeshData.h"
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
// Mesh vertices/normals are transformed by each mesh's accumulated scene-node
// transform (aiScene::mRootNode), so multi-node scenes (e.g. FBX) come out in
// world space. Files with an identity root transform (OBJ/STL/PLY) are
// unaffected.
//
// Returns nullptr on failure.
EMSCRIPTEN_KEEPALIVE TModelImporter* ModelImporter_loadFromBuffer(const uint8_t* data, size_t size,
                                                              const char* extensionHint);

// Get mesh count
EMSCRIPTEN_KEEPALIVE int ModelImporter_getMeshCount(TModelImporter* importer);

// Fill [outMesh] with the flat data of mesh [meshIndex] (name, material name,
// positions, normals, first UV channel, triangle indices). One FFI crossing
// per mesh: replaces the former per-attribute getters.
//
// The caller owns the copied buffers/strings and releases them with
// MeshData_dispose. Returns 0 on success, non-zero on failure (out of range).
EMSCRIPTEN_KEEPALIVE int ModelImporter_getMesh(TModelImporter* importer, int meshIndex,
                                              TMeshData* outMesh);

// Free the importer and all associated resources
EMSCRIPTEN_KEEPALIVE void ModelImporter_destroy(TModelImporter* importer);

#ifdef __cplusplus
}
#endif
