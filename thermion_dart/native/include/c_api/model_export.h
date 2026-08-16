#pragma once

#include "APIExport.h"
#include "TMeshData.h"
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

// Returns true iff Assimp model export was compiled into this build
// (i.e. THERMION_ASSIMP was defined at compile time — the same flag that
// gates ModelImporter). Always available; the rest of this API is only
// present when this returns true.
//
// Only FBX export is compiled into the libassimp shipped in the Filament
// artifacts (see scripts/patch_libassimp_tnt.py, which enables the FBX
// exporter sources and disables every other exporter).
EMSCRIPTEN_KEEPALIVE bool ModelExporter_isSupported();

// Export [meshCount] meshes — the same flat data ModelImporter_getMesh
// produces — into a single FBX scene held in memory, and return it as a
// malloc'd buffer written through [outSize].
//
// [formatId] selects the Assimp export format id: "fbx" (binary FBX, the
// default when nullptr/"") or "fbxa" (ASCII FBX). Any other id fails — no
// other exporter is compiled in.
//
// Scene layout: one aiMesh + one aiNode (identity transform, named after
// mesh.name) per input mesh, all parented under a single root node. FBX
// requires a material per mesh, so each mesh also gets an aiMaterial whose
// name is mesh.materialName (or a generated "Material<index>" when null).
// Positions/normals/UV channel 0/indices are copied as-is; meshes without
// indices are exported with sequential indices. Only triangle lists are
// supported (PRIMITIVETYPE_TRIANGLES), which is what the importers produce.
//
// The exporter may also produce auxiliary files alongside the model (the
// first blob is the model itself); those are logged and dropped — the
// returned buffer holds the model file only.
//
// Returns nullptr on failure. The caller owns the returned buffer and
// releases it with ModelExporter_disposeBuffer.
EMSCRIPTEN_KEEPALIVE uint8_t* ModelExporter_exportToBuffer(
    const TMeshData* meshes, int meshCount, const char* formatId,
    int64_t* outSize);

// Free a buffer returned by ModelExporter_exportToBuffer. No-op on nullptr.
EMSCRIPTEN_KEEPALIVE void ModelExporter_disposeBuffer(uint8_t* data);

#ifdef __cplusplus
}
#endif
