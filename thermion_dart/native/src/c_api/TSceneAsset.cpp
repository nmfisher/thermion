#include "rendering/EngineApiLock.hpp"

#include "c_api/TSceneAsset.h"
#include "Log.hpp"

#include "scene/GeometrySceneAsset.hpp"
#include "scene/SceneAsset.hpp"

using namespace thermion;

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
        TPrimitiveType tPrimitiveType,
        TVertexBufferStorageMode vertexBufferStorageMode,
        Aabb3 boundingBox
    ) {
        THERMION_ENGINE_API_GUARD;
        auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
        auto *vertexBuffer = reinterpret_cast<filament::VertexBuffer *>(tVertexBuffer);
        auto *indexBuffer = reinterpret_cast<filament::IndexBuffer *>(tIndexBuffer);
        auto **matInstances = reinterpret_cast<filament::MaterialInstance **>(materialInstances);
        auto primitiveType = static_cast<filament::RenderableManager::PrimitiveType>(tPrimitiveType);

        // Convert Aabb3 to filament::Box
        filament::Box box;
        box.set(
            filament::math::float3{
                boundingBox.centerX - boundingBox.halfExtentX,
                boundingBox.centerY - boundingBox.halfExtentY,
                boundingBox.centerZ - boundingBox.halfExtentZ
            },
            filament::math::float3{
                boundingBox.centerX + boundingBox.halfExtentX,
                boundingBox.centerY + boundingBox.halfExtentY,
                boundingBox.centerZ + boundingBox.halfExtentZ
            }
        );

        // Create the GeometrySceneAsset directly
        auto *sceneAsset = new GeometrySceneAsset(
            engine,
            vertexBuffer,
            indexBuffer,
            matInstances,
            materialInstanceCount,
            primitiveType,
            box,
            vertexBufferStorageMode,
            nullptr  // instanceOwner - this is not an instance
        );

        return reinterpret_cast<TSceneAsset *>(sceneAsset);
    }

    EMSCRIPTEN_KEEPALIVE TSceneAssetType SceneAsset_getType(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        return static_cast<TSceneAssetType>(asset->getType());
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_destroy(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if(asset->isInstance()) {
            TRACE("Destroyed instance");
            asset->getInstanceOwner()->destroyInstance(asset);
        } else {
            delete asset;
            TRACE("Destroyed asset");
        }
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_addToScene(TSceneAsset *tSceneAsset, TScene *tScene) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *scene = reinterpret_cast<Scene*>(tScene);
        asset->addAllEntities(scene);
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_removeFromScene(TSceneAsset *tSceneAsset, TScene *tScene) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *scene = reinterpret_cast<Scene*>(tScene);
        asset->removeAllEntities(scene);
    }

    EMSCRIPTEN_KEEPALIVE EntityId SceneAsset_getEntity(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return utils::Entity::smuggle(asset->getEntity());
    }

	EMSCRIPTEN_KEEPALIVE int SceneAsset_getChildEntityCount(TSceneAsset* tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getChildEntityCount();
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_getChildEntities(TSceneAsset* tSceneAsset, EntityId *out)
    {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto entities = asset->getChildEntities();
        for(int i = 0; i < asset->getChildEntityCount(); i++) {
            out[i] = utils::Entity::smuggle(entities[i]);
        }
    }

     EMSCRIPTEN_KEEPALIVE EntityId *SceneAsset_getCameraEntities(TSceneAsset* tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return reinterpret_cast<EntityId *>(const_cast<Entity *>(asset->getCameraEntities()));
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getCameraEntityCount(TSceneAsset* tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getCameraEntityCount();
    }

    EMSCRIPTEN_KEEPALIVE EntityId *SceneAsset_getLightEntities(TSceneAsset* tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return reinterpret_cast<EntityId *>(const_cast<Entity *>(asset->getLightEntities()));
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getLightEntityCount(TSceneAsset* tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getLightEntityCount();
    }

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_getInstance(TSceneAsset *tSceneAsset, int index) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *instance = asset->getInstanceAt(index);
        return reinterpret_cast<TSceneAsset*>(instance);
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getInstanceCount(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getInstanceCount();
    }

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createInstance(TSceneAsset *tSceneAsset, TMaterialInstance **tMaterialInstances, int materialInstanceCount)
    {
        THERMION_ENGINE_API_GUARD;
        auto *materialInstances = reinterpret_cast<MaterialInstance **>(tMaterialInstances);
        auto *sceneAsset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *instance = sceneAsset->createInstance(materialInstances, materialInstanceCount);
        return reinterpret_cast<TSceneAsset *>(instance);
    }

    EMSCRIPTEN_KEEPALIVE Aabb3 SceneAsset_getBoundingBox(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto box = asset->getBoundingBox();
        return Aabb3{box.center().x, box.center().y, box.center().z, box.extent().x, box.extent().y, box.extent().z};
    }

    EMSCRIPTEN_KEEPALIVE uint32_t SceneAsset_getGeometryCapabilities(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        return reinterpret_cast<SceneAsset*>(tSceneAsset)->getGeometryCapabilities();
    }

    EMSCRIPTEN_KEEPALIVE bool SceneAsset_supportsFlatShading(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        return reinterpret_cast<SceneAsset*>(tSceneAsset)->supportsFlatShading();
    }

    EMSCRIPTEN_KEEPALIVE TVertexBuffer *SceneAsset_getVertexBuffer(TSceneAsset *tSceneAsset, int primitiveIndex) {
        THERMION_ENGINE_API_GUARD;
        if (primitiveIndex < 0) {
            return nullptr;
        }
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *vertexBuffer = asset->getVertexBuffer(static_cast<size_t>(primitiveIndex));
        return reinterpret_cast<TVertexBuffer *>(vertexBuffer);
    }

    EMSCRIPTEN_KEEPALIVE TVertexBufferStorageMode SceneAsset_getVertexBufferStorageMode(
        TSceneAsset *tSceneAsset,
        int primitiveIndex) {
        THERMION_ENGINE_API_GUARD;
        if (primitiveIndex < 0) {
            return VERTEX_BUFFER_STORAGE_MODE_UNKNOWN;
        }
        return reinterpret_cast<SceneAsset*>(tSceneAsset)->getVertexBufferStorageMode(
            static_cast<size_t>(primitiveIndex));
    }

    EMSCRIPTEN_KEEPALIVE TIndexBuffer *SceneAsset_getIndexBuffer(TSceneAsset *tSceneAsset, int primitiveIndex) {
        THERMION_ENGINE_API_GUARD;
        if (primitiveIndex < 0) {
            return nullptr;
        }
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *indexBuffer = asset->getIndexBuffer(static_cast<size_t>(primitiveIndex));
        return reinterpret_cast<TIndexBuffer *>(indexBuffer);
    }

    EMSCRIPTEN_KEEPALIVE int SceneAsset_getPrimitiveOffsetForEntity(TSceneAsset *tSceneAsset, EntityId entity) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getPrimitiveOffsetForEntity(utils::Entity::import(entity));
    }


    EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceData(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        asset->releaseSourceData();
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShading(TSceneAsset *tSceneAsset, bool flatShading) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        asset->setFlatShading(flatShading);
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_getBones(TSceneAsset *tSceneAsset, size_t skinIndex, EntityId *out) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *bones = asset->getBones(skinIndex);
        for(int i = 0; i < asset->getBoneCount(skinIndex); i++) {
            out[i] = utils::Entity::smuggle(bones[i]);
        }
    }


    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getBoneCount(TSceneAsset *tSceneAsset, size_t skinIndex) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getBoneCount(skinIndex);
    }

    EMSCRIPTEN_KEEPALIVE const char *SceneAsset_getBoneName(TSceneAsset *tSceneAsset, size_t skinIndex, size_t boneIndex) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getBoneName(skinIndex, boneIndex);
    }

#ifdef __cplusplus
}
#endif
