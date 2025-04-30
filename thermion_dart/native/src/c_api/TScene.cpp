#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif 

#include "c_api/TScene.h"

#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/IndirectLight.h>
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
            TRACE("Added entity %d", entityId);
        }
        
        EMSCRIPTEN_KEEPALIVE void Scene_removeEntity(TScene* tScene, EntityId entityId) {
            auto *scene = reinterpret_cast<Scene *>(tScene);
            scene->remove(utils::Entity::import(entityId));
            TRACE("Removed entity %d", entityId);
        }

        EMSCRIPTEN_KEEPALIVE void Scene_setSkybox(TScene* tScene, TSkybox *tSkybox) {
            auto *scene = reinterpret_cast<Scene *>(tScene);
            auto *skybox = reinterpret_cast<Skybox *>(tSkybox);
            scene->setSkybox(skybox);
            TRACE("Set skybox");
        }

        EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLight(TScene* tScene, TIndirectLight *tIndirectLight) {
            auto *scene = reinterpret_cast<Scene *>(tScene);
            auto *light = reinterpret_cast<IndirectLight *>(tIndirectLight);
            scene->setIndirectLight(light);
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
