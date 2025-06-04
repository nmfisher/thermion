#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include <gltfio/AssetLoader.h>
#include <gltfio/ResourceLoader.h>

#include <utils/NameComponentManager.h>

#include "c_api/TGltfAssetLoader.h"
#include "c_api/TSceneAsset.h"
#include "scene/GridOverlay.hpp"
#include "scene/SceneAsset.hpp"
#include "scene/GltfSceneAsset.hpp"
#include "scene/GeometrySceneAssetBuilder.hpp"

using namespace thermion;

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
        TPrimitiveType tPrimitiveType,
        TMaterialInstance **materialInstances,
		int materialInstanceCount
    ) {
        utils::Entity entity;

        auto *engine = reinterpret_cast<filament::Engine *>(tEngine);

        auto builder = GeometrySceneAssetBuilder(engine)
                           .vertices(vertices, numVertices)
                           .indices(indices, numIndices)
                           .primitiveType(static_cast<filament::RenderableManager::PrimitiveType>(tPrimitiveType));

        if (normals)
        {
            builder.normals(normals, numNormals);
        }

        if (uvs)
        {
            builder.uvs(uvs, numUvs);
        }

        builder.materials(reinterpret_cast<MaterialInstance**>(materialInstances), materialInstanceCount);

        auto sceneAsset = builder.build();

        if (!sceneAsset)
        {
            Log("Failed to create geometry");
            return std::nullptr_t();
        }

        return reinterpret_cast<TSceneAsset*>(sceneAsset.release());
        
    }

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createFromFilamentAsset(
        TEngine *tEngine,
        TGltfAssetLoader *tAssetLoader,
        TNameComponentManager *tNameComponentManager,
        TFilamentAsset *tFilamentAsset
    ) {
        auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
        auto *nameComponentManager = reinterpret_cast<utils::NameComponentManager *>(tNameComponentManager);
        auto *filamentAsset = reinterpret_cast<filament::gltfio::FilamentAsset *>(tFilamentAsset);

        auto *assetLoader = reinterpret_cast<filament::gltfio::AssetLoader *>(tAssetLoader);
        auto *sceneAsset = new GltfSceneAsset(
            filamentAsset,
            assetLoader,
            engine,
            nameComponentManager
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

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createGrid(TEngine *tEngine, TMaterial* tMaterial) {
        auto *engine = reinterpret_cast<filament::Engine *>(tEngine);
        auto *material = reinterpret_cast<filament::Material *>(tMaterial);
        auto *asset = new GridOverlay(*engine, material);
        return reinterpret_cast<TSceneAsset *>(asset);
    }
    
    EMSCRIPTEN_KEEPALIVE void SceneAsset_destroy(TSceneAsset *tSceneAsset) { 
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if(asset->isInstance()) {
            asset->getInstanceOwner()->destroyInstance(asset);
        } else {
            delete asset;
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


#ifdef __cplusplus
}
#endif

