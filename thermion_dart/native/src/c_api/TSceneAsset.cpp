 

#include <gltfio/AssetLoader.h>
#include <gltfio/ResourceLoader.h>

#include <utils/NameComponentManager.h>

#include "c_api/TGltfAssetLoader.h"
#include "c_api/TSceneAsset.h"
#include "Log.hpp"

#include "scene/GeometrySceneAsset.hpp"
#include "scene/GltfSceneAsset.hpp"
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

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createFromFilamentAsset(
        TEngine *tEngine,
        TGltfAssetLoader *tAssetLoader,
        TNameComponentManager *tNameComponentManager,
        TFilamentAsset *tFilamentAsset,
        uint32_t requiredGeometryCapabilities
    ) {
        auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
        auto *nameComponentManager = reinterpret_cast<utils::NameComponentManager *>(tNameComponentManager);
        auto *filamentAsset = reinterpret_cast<filament::gltfio::FilamentAsset *>(tFilamentAsset);

        auto *assetLoader = reinterpret_cast<filament::gltfio::AssetLoader *>(tAssetLoader);
        if (!GltfSceneAsset::supportsRequiredGeometryCapabilities(requiredGeometryCapabilities)) {
            Log("Unsupported or incompatible required geometry capabilities: 0x%x",
                requiredGeometryCapabilities);
            return nullptr;
        }
        auto *sceneAsset = new GltfSceneAsset(
            filamentAsset,
            assetLoader,
            engine,
            nameComponentManager,
            requiredGeometryCapabilities
        );

        return reinterpret_cast<TSceneAsset *>(sceneAsset);
    }
    
    EMSCRIPTEN_KEEPALIVE TFilamentAsset *SceneAsset_getFilamentAsset(TSceneAsset *tSceneAsset) {
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            Log("Error - not a gltf asset");
            return nullptr;
        }
        
        auto gltfAsset = reinterpret_cast<GltfSceneAsset *>(tSceneAsset);
        auto *filamentAsset = gltfAsset->getAsset();
        TRACE("SceneAsset %d FilamentAsset %d", sceneAsset, filamentAsset);
        return reinterpret_cast<TFilamentAsset *>(filamentAsset);
    }

    EMSCRIPTEN_KEEPALIVE TSceneAssetType SceneAsset_getType(TSceneAsset *tSceneAsset) {
        auto *asset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        return static_cast<TSceneAssetType>(asset->getType());
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_destroy(TSceneAsset *tSceneAsset) {
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
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *scene = reinterpret_cast<Scene*>(tScene);
        asset->addAllEntities(scene);
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_removeFromScene(TSceneAsset *tSceneAsset, TScene *tScene) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *scene = reinterpret_cast<Scene*>(tScene);
        asset->removeAllEntities(scene);
    }

    EMSCRIPTEN_KEEPALIVE EntityId SceneAsset_getEntity(TSceneAsset *tSceneAsset) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return utils::Entity::smuggle(asset->getEntity());
    }

	EMSCRIPTEN_KEEPALIVE int SceneAsset_getChildEntityCount(TSceneAsset* tSceneAsset) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getChildEntityCount();
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_getChildEntities(TSceneAsset* tSceneAsset, EntityId *out)
    {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto entities = asset->getChildEntities();
        for(int i = 0; i < asset->getChildEntityCount(); i++) {
            out[i] = utils::Entity::smuggle(entities[i]);
        }
    }

     EMSCRIPTEN_KEEPALIVE EntityId *SceneAsset_getCameraEntities(TSceneAsset* tSceneAsset)
    {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            auto *entities = gltfSceneAsset->getAsset()->getCameraEntities();
            return reinterpret_cast<EntityId *>(const_cast<filament::gltfio::FilamentAsset::Entity *>(entities));
        }
        else
        {
            return std::nullptr_t();
        }
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getCameraEntityCount(TSceneAsset* tSceneAsset)
    {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            return gltfSceneAsset->getAsset()->getCameraEntityCount();
        }
        
        return -1;
        
    }

    EMSCRIPTEN_KEEPALIVE EntityId *SceneAsset_getLightEntities(TSceneAsset* tSceneAsset)
    {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {            
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            auto *entities = gltfSceneAsset->getAsset()->getLightEntities();
            return reinterpret_cast<EntityId *>(const_cast<filament::gltfio::FilamentAsset::Entity *>(entities));
        }
        
        return std::nullptr_t();
        
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getLightEntityCount(TSceneAsset* tSceneAsset)
    {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {            
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            return gltfSceneAsset->getAsset()->getLightEntityCount();
        }
        
        return -1;
    }

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_getInstance(TSceneAsset *tSceneAsset, int index) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *instance = asset->getInstanceAt(index);
        return reinterpret_cast<TSceneAsset*>(instance);
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getInstanceCount(TSceneAsset *tSceneAsset) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getInstanceCount();
    }

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createInstance(TSceneAsset *tSceneAsset, TMaterialInstance **tMaterialInstances, int materialInstanceCount)
    {
        auto *materialInstances = reinterpret_cast<MaterialInstance **>(tMaterialInstances);
        auto *sceneAsset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *instance = sceneAsset->createInstance(materialInstances, materialInstanceCount);
        return reinterpret_cast<TSceneAsset *>(instance);
    }

    EMSCRIPTEN_KEEPALIVE Aabb3 SceneAsset_getBoundingBox(TSceneAsset *tSceneAsset) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto box = asset->getBoundingBox();
        return Aabb3{box.center().x, box.center().y, box.center().z, box.extent().x, box.extent().y, box.extent().z};
    }

    EMSCRIPTEN_KEEPALIVE uint32_t SceneAsset_getGeometryCapabilities(TSceneAsset *tSceneAsset) {
        return reinterpret_cast<SceneAsset*>(tSceneAsset)->getGeometryCapabilities();
    }

    EMSCRIPTEN_KEEPALIVE TVertexBuffer *SceneAsset_getVertexBuffer(TSceneAsset *tSceneAsset, int primitiveIndex) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Geometry) {
            auto geometrySceneAsset = reinterpret_cast<GeometrySceneAsset *>(asset);
            auto *vertexBuffer = geometrySceneAsset->getVertexBuffer();
            return reinterpret_cast<TVertexBuffer *>(vertexBuffer);
        }
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf) {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(
                asset->isInstance() ? asset->getInstanceOwner() : asset);
            auto *vertexBuffer = gltfSceneAsset->getPreservedVertexBuffer(primitiveIndex);
            return reinterpret_cast<TVertexBuffer *>(vertexBuffer);
        }
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE TVertexBufferStorageMode SceneAsset_getVertexBufferStorageMode(
        TSceneAsset *tSceneAsset,
        int primitiveIndex) {
        if (primitiveIndex < 0) {
            return VERTEX_BUFFER_STORAGE_MODE_UNKNOWN;
        }
        return reinterpret_cast<SceneAsset*>(tSceneAsset)->getVertexBufferStorageMode(
            static_cast<size_t>(primitiveIndex));
    }

    EMSCRIPTEN_KEEPALIVE TIndexBuffer *SceneAsset_getIndexBuffer(TSceneAsset *tSceneAsset, int primitiveIndex) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Geometry) {
            auto geometrySceneAsset = reinterpret_cast<GeometrySceneAsset *>(asset);
            auto *indexBuffer = geometrySceneAsset->getIndexBuffer();
            return reinterpret_cast<TIndexBuffer *>(indexBuffer);
        }
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf) {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(
                asset->isInstance() ? asset->getInstanceOwner() : asset);
            auto *indexBuffer = gltfSceneAsset->getPreservedIndexBuffer(primitiveIndex);
            return reinterpret_cast<TIndexBuffer *>(indexBuffer);
        }
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE int SceneAsset_getPrimitiveOffsetForEntity(TSceneAsset *tSceneAsset, EntityId entity) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() != SceneAsset::SceneAssetType::Gltf) {
            return -1;
        }
        auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(
            asset->isInstance() ? asset->getInstanceOwner() : asset);
        // Convert EntityId to utils::Entity for the internal method
        return gltfSceneAsset->getPrimitiveOffsetForEntity(utils::Entity::import(entity));
    }


    EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceData(TSceneAsset *tSceneAsset) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() != SceneAsset::SceneAssetType::Gltf) {
            Log("releaseSourceData only supported on glTF assets");
            return;
        }
        if (asset->isInstance()) {
            Log("releaseSourceData must be called on the owning asset, not an instance");
            return;
        }
        auto *gltfAsset = reinterpret_cast<GltfSceneAsset*>(tSceneAsset);
        gltfAsset->releaseSourceData();
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShading(TSceneAsset *tSceneAsset, bool flatShading) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() != SceneAsset::SceneAssetType::Gltf) {
            Log("setFlatShading only supported on glTF assets");
            return;
        }
        auto *gltfAsset = reinterpret_cast<GltfSceneAsset*>(tSceneAsset);
        gltfAsset->setFlatShading(flatShading);
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_getBones(TSceneAsset *tSceneAsset, size_t skinIndex, EntityId *out) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *bones = asset->getBones(skinIndex);
        for(int i = 0; i < asset->getBoneCount(skinIndex); i++) {
            out[i] = utils::Entity::smuggle(bones[i]);
        }
    }


    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getBoneCount(TSceneAsset *tSceneAsset, size_t skinIndex) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getBoneCount(skinIndex);
    }

    EMSCRIPTEN_KEEPALIVE const char *SceneAsset_getBoneName(TSceneAsset *tSceneAsset, size_t skinIndex, size_t boneIndex) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        return asset->getBoneName(skinIndex, boneIndex);
    }

#ifdef __cplusplus
}
#endif
