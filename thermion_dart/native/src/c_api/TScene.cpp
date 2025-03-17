#include "c_api/TScene.h"

#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/Material.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/TransformManager.h>
#include <filament/View.h>

#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>

#include "Log.hpp"

#ifdef __cplusplus
namespace thermion
{
    extern "C"
    {
        using namespace filament;
#endif

        EMSCRIPTEN_KEEPALIVE void Scene_addEntity(TScene *tScene, EntityId entityId)
        {
            auto *scene = reinterpret_cast<Scene *>(tScene);
            scene->addEntity(utils::Entity::import(entityId));
        }

        EMSCRIPTEN_KEEPALIVE void Scene_setSkybox(TScene* tScene, TSkybox *tSkybox) {
            auto *scene = reinterpret_cast<Scene *>(tScene);
            auto *skybox = reinterpret_cast<Skybox *>(tSkybox);
            scene->setSkybox(skybox);
        }

        EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAsset(TScene* tScene, TFilamentAsset *tAsset) { 
            auto *scene = reinterpret_cast<Scene *>(tScene);
            auto *asset = reinterpret_cast<gltfio::FilamentAsset*>(tAsset);
            scene->addEntities(asset->getEntities(), asset->getEntityCount());
        }


#ifdef __cplusplus
    }
}
#endif
