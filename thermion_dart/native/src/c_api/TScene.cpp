#include "c_api/TScene.h"

#include <filament/Engine.h>
#include <filament/Fence.h>
#include <filament/IndirectLight.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
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

        EMSCRIPTEN_KEEPALIVE TSkybox* Scene_getSkybox(TScene* tScene) {
            auto *scene = reinterpret_cast<Scene *>(tScene);
            return reinterpret_cast<TSkybox*>(scene->getSkybox());
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

        EMSCRIPTEN_KEEPALIVE size_t Scene_scanForMaterial(TScene *tScene, TRenderableManager *tRenderableManager,
                TMaterial *tMaterial, EntityId *outEntities, uint32_t *outPrimitives,
                TMaterialInstance **outInstances, size_t capacity)
        {
            auto *scene = reinterpret_cast<Scene *>(tScene);
            auto *renderableManager = reinterpret_cast<RenderableManager *>(tRenderableManager);
            auto *material = reinterpret_cast<Material *>(tMaterial);

            size_t count = 0;
            scene->forEach(
                [&](utils::Entity entity)
                {
                    if (!renderableManager->hasComponent(entity))
                    {
                        return;
                    }
                    auto renderable = renderableManager->getInstance(entity);
                    auto primitiveCount = renderableManager->getPrimitiveCount(renderable);
                    for (size_t primitive = 0; primitive < primitiveCount; primitive++)
                    {
                        auto *materialInstance = renderableManager->getMaterialInstanceAt(renderable, primitive);
                        if (materialInstance == nullptr || materialInstance->getMaterial() != material)
                        {
                            continue;
                        }
                        // Each output buffer is optional so callers can request
                        // a subset (e.g. entities+primitives but not
                        // instances); guard them individually.
                        if (count < capacity)
                        {
                            if (outEntities != nullptr)
                            {
                                outEntities[count] = (EntityId)entity.getId();
                            }
                            if (outPrimitives != nullptr)
                            {
                                outPrimitives[count] = (uint32_t)primitive;
                            }
                            if (outInstances != nullptr)
                            {
                                outInstances[count] = reinterpret_cast<TMaterialInstance *>(materialInstance);
                            }
                        }
                        count++;
                    }
                });
            return count;
        }


#ifdef __cplusplus
    }
}
#endif
