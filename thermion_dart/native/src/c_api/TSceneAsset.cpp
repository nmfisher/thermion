#include "c_api/TSceneAsset.h"
#include "scene/SceneAsset.hpp"
#include "scene/GltfSceneAsset.hpp"

using namespace thermion;

#ifdef __cplusplus

extern "C"
{
#endif

    EMSCRIPTEN_KEEPALIVE void SceneAsset_addToScene(TSceneAsset *tSceneAsset, TScene *tScene) {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *scene = reinterpret_cast<Scene*>(tScene);
        asset->addAllEntities(scene);
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

     EMSCRIPTEN_KEEPALIVE const utils::Entity *SceneAsset_getCameraEntities(TSceneAsset* tSceneAsset)
    {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            return gltfSceneAsset->getAsset()->getCameraEntities();
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

    EMSCRIPTEN_KEEPALIVE const utils::Entity *SceneAsset_getLightEntities(TSceneAsset* tSceneAsset)
    {
        auto *asset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        if (asset->getType() == SceneAsset::SceneAssetType::Gltf && !asset->isInstance())
        {            
            auto gltfSceneAsset = reinterpret_cast<GltfSceneAsset *>(asset);
            return gltfSceneAsset->getAsset()->getLightEntities();
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

    EMSCRIPTEN_KEEPALIVE TSceneAsset *SceneAsset_createInstance(TSceneAsset *tSceneAsset, TMaterialInstance **tMaterialInstances, int materialInstanceCount)
    {
        auto *materialInstances = reinterpret_cast<MaterialInstance **>(tMaterialInstances);
        auto *sceneAsset = reinterpret_cast<SceneAsset*>(tSceneAsset);
        auto *instance = sceneAsset->createInstance(materialInstances, materialInstanceCount);
        return reinterpret_cast<TSceneAsset *>(instance);
    }


#ifdef __cplusplus
}
#endif

