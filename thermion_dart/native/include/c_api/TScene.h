#ifndef _T_SCENE_H
#define _T_SCENE_H

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
EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLight(TScene* tScene, TIndirectLight *tIndirectLight);
EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAsset(TScene* tScene, TFilamentAsset *asset);



#ifdef __cplusplus
}
#endif

#endif