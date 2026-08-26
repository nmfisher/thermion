
#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createFromBuffers(
        TEngine *tEngine,
        TVertexBuffer *tVertexBuffer,
        TIndexBuffer *tIndexBuffer,
        TMaterialInstance **materialInstances,
        int materialInstanceCount,
        enum TPrimitiveType tPrimitiveType,
        enum TVertexBufferStorageMode vertexBufferStorageMode,
        Aabb3 boundingBox
    );
    EMSCRIPTEN_KEEPALIVE TSceneAsset * SceneAsset_createFromFilamentAsset(
        TEngine *tEngine,
        TGltfAssetLoader *tAssetLoader,
        TNameComponentManager *tNameComponentManager,
        TFilamentAsset *tFilamentAsset,
        uint32_t requiredGeometryCapabilities
    );
    EMSCRIPTEN_KEEPALIVE TFilamentAsset *SceneAsset_getFilamentAsset(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE enum TSceneAssetType SceneAsset_getType(TSceneAsset *tSceneAsset);
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
    EMSCRIPTEN_KEEPALIVE uint32_t SceneAsset_getGeometryCapabilities(TSceneAsset *asset);
    EMSCRIPTEN_KEEPALIVE TVertexBuffer *SceneAsset_getVertexBuffer(TSceneAsset *tSceneAsset, int primitiveIndex);
    EMSCRIPTEN_KEEPALIVE TVertexBufferStorageMode SceneAsset_getVertexBufferStorageMode(TSceneAsset *tSceneAsset, int primitiveIndex);
    EMSCRIPTEN_KEEPALIVE TIndexBuffer *SceneAsset_getIndexBuffer(TSceneAsset *tSceneAsset, int primitiveIndex);
    EMSCRIPTEN_KEEPALIVE int SceneAsset_getPrimitiveOffsetForEntity(TSceneAsset *tSceneAsset, EntityId entity);
    EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceData(TSceneAsset *tSceneAsset);
    EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShading(TSceneAsset *tSceneAsset, bool flatShading);
    EMSCRIPTEN_KEEPALIVE void SceneAsset_getBones(TSceneAsset *tSceneAsset, size_t skinIndex, EntityId *out);
    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getBoneCount(TSceneAsset *tSceneAsset, size_t skinIndex);
    EMSCRIPTEN_KEEPALIVE const char *SceneAsset_getBoneName(TSceneAsset *tSceneAsset, size_t skinIndex, size_t boneIndex);

#ifdef __cplusplus
}
#endif
