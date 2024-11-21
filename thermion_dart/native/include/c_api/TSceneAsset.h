
#pragma once

#include <utils/Entity.h>
#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif
    EMSCRIPTEN_KEEPALIVE void SceneAsset_addToScene(TSceneAsset *tSceneAsset, TScene *tScene);
    EMSCRIPTEN_KEEPALIVE EntityId SceneAsset_getEntity(TSceneAsset *tSceneAsset);
	EMSCRIPTEN_KEEPALIVE int SceneAsset_getChildEntityCount(TSceneAsset* tSceneAsset);
    EMSCRIPTEN_KEEPALIVE void SceneAsset_getChildEntities(TSceneAsset* tSceneAsset, EntityId *out);
    EMSCRIPTEN_KEEPALIVE const utils::Entity *SceneAsset_getCameraEntities(TSceneAsset* tSceneAsset);
    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getCameraEntityCount(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE const utils::Entity *SceneAsset_getLightEntities(TSceneAsset* tSceneAsset);
    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getLightEntityCount(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_getInstance(TSceneAsset *tSceneAsset, int index);
    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getInstanceCount(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE TSceneAsset * SceneAsset_createInstance(TSceneAsset *asset, TMaterialInstance **materialInstances, int materialInstanceCount);
    
#ifdef __cplusplus
}
#endif

