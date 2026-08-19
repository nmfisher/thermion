#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"
#include "TTexture.h"

#ifdef __cplusplus
extern "C"
{
#endif

EMSCRIPTEN_KEEPALIVE void Scene_addEntity(TScene* tScene, EntityId entityId);
EMSCRIPTEN_KEEPALIVE void Scene_removeEntity(TScene* tScene, EntityId entityId);
EMSCRIPTEN_KEEPALIVE void Scene_setSkybox(TScene* tScene, TSkybox *skybox);
EMSCRIPTEN_KEEPALIVE TSkybox* Scene_getSkybox(TScene* tScene);
EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLight(TScene* tScene, TIndirectLight *tIndirectLight);
EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAsset(TScene* tScene, TFilamentAsset *asset);

/// Walks every renderable primitive in the scene and records the ones whose
/// current MaterialInstance belongs to [tMaterial].
///
/// Returns the TOTAL number of matches (which may exceed [capacity]). When
/// [outEntities]/[outPrimitives]/[outInstances] are non-null, up to
/// [capacity] matches are written to them. Call once with null buffers to
/// size the output, then again to fetch it.
EMSCRIPTEN_KEEPALIVE size_t Scene_scanForMaterial(TScene* tScene, TRenderableManager *tRenderableManager, TMaterial *tMaterial,
        EntityId *outEntities, uint32_t *outPrimitives, TMaterialInstance **outInstances, size_t capacity);

#ifdef __cplusplus
}
#endif
