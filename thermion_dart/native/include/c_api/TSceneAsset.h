
#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif
    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createGeometry(
        TEngine *tEngine, 
        float *vertices,
        uint32_t numVertices,
        float *normals,
        uint32_t numNormals,
        float *uvs,
        uint32_t numUvs,
        uint16_t *indices,
        uint32_t numIndices,
        enum TPrimitiveType tPrimitiveType,
        TMaterialInstance **materialInstances,
		int materialInstanceCount
    );
    EMSCRIPTEN_KEEPALIVE TSceneAsset * SceneAsset_createFromFilamentAsset(
        TEngine *tEngine,
        TGltfAssetLoader *tAssetLoader,
        TNameComponentManager *tNameComponentManager,
        TFilamentAsset *tFilamentAsset    
    );
    EMSCRIPTEN_KEEPALIVE TFilamentAsset *SceneAsset_getFilamentAsset(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createGrid(TEngine *tEngine, TMaterial * tMaterial);
    EMSCRIPTEN_KEEPALIVE void SceneAsset_destroy(TSceneAsset *tSceneAsset);   
    EMSCRIPTEN_KEEPALIVE void SceneAsset_addToScene(TSceneAsset *tSceneAsset, TScene *tScene);
    EMSCRIPTEN_KEEPALIVE void SceneAsset_removeFromScene(TSceneAsset *tSceneAsset, TScene *tScene);
    EMSCRIPTEN_KEEPALIVE EntityId SceneAsset_getEntity(TSceneAsset *tSceneAsset);
	EMSCRIPTEN_KEEPALIVE int SceneAsset_getChildEntityCount(TSceneAsset* tSceneAsset);
    EMSCRIPTEN_KEEPALIVE void SceneAsset_getChildEntities(TSceneAsset* tSceneAsset, EntityId *out);
    EMSCRIPTEN_KEEPALIVE EntityId *SceneAsset_getCameraEntities(TSceneAsset* tSceneAsset);
    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getCameraEntityCount(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE EntityId *SceneAsset_getLightEntities(TSceneAsset* tSceneAsset);
    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getLightEntityCount(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_getInstance(TSceneAsset *tSceneAsset, int index);
    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getInstanceCount(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE TSceneAsset * SceneAsset_createInstance(TSceneAsset *asset, TMaterialInstance **materialInstances, int materialInstanceCount);
    EMSCRIPTEN_KEEPALIVE Aabb3 SceneAsset_getBoundingBox(TSceneAsset *asset);
        
#ifdef __cplusplus
}
#endif

