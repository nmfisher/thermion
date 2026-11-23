#include "rendering/EngineApiLock.hpp"

#include "ThermionFeatures.h"

#include <utils/NameComponentManager.h>

#include "c_api/TGltfAssetLoader.h"
#include "c_api/TSceneAsset.h"
#include "Log.hpp"

#include "scene/GeometrySceneAsset.hpp"
#include "scene/SceneAsset.hpp"

#if THERMION_ENABLE_GLTF
#include <gltfio/AssetLoader.h>
#include <gltfio/ResourceLoader.h>

#include "scene/GltfSceneAsset.hpp"
#endif

// Pattern B (docs/feature-optout-proposal.md §5.2, decision D1): this file
// mixes core procedural code (SceneAsset_createFromBuffers, shared
// entity/light/camera access, instancing, destruction) with glTF-only entry
// points, so only the glTF branches are guarded. The procedural entry points
// stay live in `features.gltf: false` builds.

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

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createFromFilamentAsset(
        TEngine *tEngine,
        TGltfAssetLoader *tAssetLoader,
        TNameComponentManager *tNameComponentManager,
        TFilamentAsset *tFilamentAsset,
        uint32_t requiredGeometryCapabilities
    ) {
#if THERMION_ENABLE_GLTF
        THERMION_ENGINE_API_GUARD;
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

        if ((sceneAsset->getGeometryCapabilities() & requiredGeometryCapabilities) !=
            requiredGeometryCapabilities) {
            Log("Failed to provide required geometry capabilities: requested 0x%x, provided 0x%x",
                requiredGeometryCapabilities, sceneAsset->getGeometryCapabilities());
            delete sceneAsset;
            return nullptr;
        }

        return reinterpret_cast<TSceneAsset *>(sceneAsset);
#else
        Log("SceneAsset_createFromFilamentAsset: glTF support is disabled in this build (features.gltf: false)");
        return nullptr;
#endif
    }
    
    EMSCRIPTEN_KEEPALIVE TFilamentAsset *SceneAsset_getFilamentAsset(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto sceneAsset = reinterpret_cast<SceneAsset *>(tSceneAsset);
        if(sceneAsset->getType() != SceneAsset::SceneAssetType::Gltf) {
            Log("Error - not a gltf asset");
            return nullptr;
        }
        
#if THERMION_ENABLE_GLTF
        // A GltfSceneAssetInstance is Gltf-typed too but is not a
        // GltfSceneAsset; resolve it to its owner like the buffer getters do.
        auto gltfAsset = reinterpret_cast<GltfSceneAsset *>(
            sceneAsset->isInstance() ? sceneAsset->getInstanceOwner() : sceneAsset);
        auto *filamentAsset = gltfAsset->getAsset();
        TRACE("SceneAsset %d FilamentAsset %d", sceneAsset, filamentAsset);
        return reinterpret_cast<TFilamentAsset *>(filamentAsset);
#else
        // No asset can be Gltf-typed in a build without gltfio.
        return nullptr;
#endif
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
#if THERMION_ENABLE_GLTF
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            auto *entities = gltfSceneAsset->getAsset()->getCameraEntities();
            return reinterpret_cast<EntityId *>(const_cast<filament::gltfio::FilamentAsset::Entity *>(entities));
        }
        else
#endif
        {
            return std::nullptr_t();
        }
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getCameraEntityCount(TSceneAsset* tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
#if THERMION_ENABLE_GLTF
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            return gltfSceneAsset->getAsset()->getCameraEntityCount();
        }
#endif
        
        return -1;
        
    }

    EMSCRIPTEN_KEEPALIVE EntityId *SceneAsset_getLightEntities(TSceneAsset* tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
#if THERMION_ENABLE_GLTF
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {            
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            auto *entities = gltfSceneAsset->getAsset()->getLightEntities();
            return reinterpret_cast<EntityId *>(const_cast<filament::gltfio::FilamentAsset::Entity *>(entities));
        }
#endif
        
        return std::nullptr_t();
        
    }

    EMSCRIPTEN_KEEPALIVE size_t SceneAsset_getLightEntityCount(TSceneAsset* tSceneAsset)
    {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
#if THERMION_ENABLE_GLTF
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {            
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            return gltfSceneAsset->getAsset()->getLightEntityCount();
        }
#endif
        
        return -1;
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
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Geometry) {
            auto geometrySceneAsset = reinterpret_cast<GeometrySceneAsset *>(asset);
            auto *vertexBuffer = geometrySceneAsset->getVertexBuffer();
            return reinterpret_cast<TVertexBuffer *>(vertexBuffer);
        }
#if THERMION_ENABLE_GLTF
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf) {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(
                asset->isInstance() ? asset->getInstanceOwner() : asset);
            auto *vertexBuffer = gltfSceneAsset->getPreservedVertexBuffer(primitiveIndex);
            return reinterpret_cast<TVertexBuffer *>(vertexBuffer);
        }
#endif
        return nullptr;
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
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Geometry) {
            auto geometrySceneAsset = reinterpret_cast<GeometrySceneAsset *>(asset);
            auto *indexBuffer = geometrySceneAsset->getIndexBuffer();
            return reinterpret_cast<TIndexBuffer *>(indexBuffer);
        }
#if THERMION_ENABLE_GLTF
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf) {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(
                asset->isInstance() ? asset->getInstanceOwner() : asset);
            auto *indexBuffer = gltfSceneAsset->getPreservedIndexBuffer(primitiveIndex);
            return reinterpret_cast<TIndexBuffer *>(indexBuffer);
        }
#endif
        return nullptr;
    }

    EMSCRIPTEN_KEEPALIVE int SceneAsset_getPrimitiveOffsetForEntity(TSceneAsset *tSceneAsset, EntityId entity) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() != SceneAsset::SceneAssetType::Gltf) {
            return -1;
        }
#if THERMION_ENABLE_GLTF
        auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(
            asset->isInstance() ? asset->getInstanceOwner() : asset);
        // Convert EntityId to utils::Entity for the internal method
        return gltfSceneAsset->getPrimitiveOffsetForEntity(utils::Entity::import(entity));
#else
        // No glTF assets exist in this build; keep the export's contract.
        return -1;
#endif
    }


    EMSCRIPTEN_KEEPALIVE void SceneAsset_releaseSourceData(TSceneAsset *tSceneAsset) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() != SceneAsset::SceneAssetType::Gltf) {
            Log("releaseSourceData only supported on glTF assets");
            return;
        }
        if (asset->isInstance()) {
            Log("releaseSourceData must be called on the owning asset, not an instance");
            return;
        }
#if THERMION_ENABLE_GLTF
        auto *gltfAsset = reinterpret_cast<GltfSceneAsset*>(tSceneAsset);
        gltfAsset->releaseSourceData();
#endif
    }

    EMSCRIPTEN_KEEPALIVE void SceneAsset_setFlatShading(TSceneAsset *tSceneAsset, bool flatShading) {
        THERMION_ENGINE_API_GUARD;
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() != SceneAsset::SceneAssetType::Gltf) {
            Log("setFlatShading only supported on glTF assets");
            return;
        }
#if THERMION_ENABLE_GLTF
        auto *gltfAsset = reinterpret_cast<GltfSceneAsset*>(
            asset->isInstance() ? asset->getInstanceOwner() : asset);
        gltfAsset->setFlatShading(flatShading);
#endif
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
