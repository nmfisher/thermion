#ifndef _T_SCENE_H
#define _T_SCENE_H

#include "APIExport.h"
#include "APIBoundaryTypes.h"
#include "TMaterialInstance.h"
#include "TTexture.h"
#include "ResourceBuffer.hpp"
#include "MathUtils.hpp"

#ifdef __cplusplus
extern "C"
{
#endif



EMSCRIPTEN_KEEPALIVE void Scene_addEntity(TScene* tScene, EntityId entityId);
EMSCRIPTEN_KEEPALIVE void Scene_setSkybox(TScene* tScene, TSkybox *skybox);


#ifdef __cplusplus
}
#endif

#endif