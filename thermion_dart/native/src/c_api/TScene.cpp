#include "rendering/EngineApiLock.hpp"
#include "ThermionFeatures.h"
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

#if THERMION_ENABLE_GLTF
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#endif

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
            THERMION_ENGINE_API_GUARD;
            auto *scene = reinterpret_cast<Scene *>(tScene);
            scene->addEntity(utils::Entity::import(entityId));
            TRACE("Added entity %d", entityId);
        }
        
        EMSCRIPTEN_KEEPALIVE void Scene_removeEntity(TScene* tScene, EntityId entityId) {
            THERMION_ENGINE_API_GUARD;
            auto *scene = reinterpret_cast<Scene *>(tScene);
            scene->remove(utils::Entity::import(entityId));
            TRACE("Removed entity %d", entityId);
        }

        EMSCRIPTEN_KEEPALIVE void Scene_setSkybox(TScene* tScene, TSkybox *tSkybox) {
            THERMION_ENGINE_API_GUARD;
            auto *scene = reinterpret_cast<Scene *>(tScene);
            auto *skybox = reinterpret_cast<Skybox *>(tSkybox);
            scene->setSkybox(skybox);
            TRACE("Set skybox");
        }

        EMSCRIPTEN_KEEPALIVE TSkybox* Scene_getSkybox(TScene* tScene) {
            THERMION_ENGINE_API_GUARD;
            auto *scene = reinterpret_cast<Scene *>(tScene);
            return reinterpret_cast<TSkybox*>(scene->getSkybox());
        }

        EMSCRIPTEN_KEEPALIVE void Scene_setIndirectLight(TScene* tScene, TIndirectLight *tIndirectLight) {
            THERMION_ENGINE_API_GUARD;
            auto *scene = reinterpret_cast<Scene *>(tScene);
            auto *light = reinterpret_cast<IndirectLight *>(tIndirectLight);
            scene->setIndirectLight(light);
        }

        EMSCRIPTEN_KEEPALIVE void Scene_addFilamentAsset(TScene* tScene, TFilamentAsset *tAsset) {
#if THERMION_ENABLE_GLTF
            THERMION_ENGINE_API_GUARD;
            auto *scene = reinterpret_cast<Scene *>(tScene);
            auto *asset = reinterpret_cast<gltfio::FilamentAsset*>(tAsset);
            scene->addEntities(asset->getEntities(), asset->getEntityCount());
#else
            // Stub (docs/feature-optout-proposal.md §5.4): no glTF assets exist
            // in this build, so there is nothing to add.
#endif
        }


#ifdef __cplusplus
    }
}
#endif
