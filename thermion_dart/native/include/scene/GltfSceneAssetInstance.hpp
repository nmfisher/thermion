#pragma once

#include <memory>
#include <vector>

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/MaterialProvider.h>

#include <utils/NameComponentManager.h>

#include "scene/SceneAsset.hpp"

namespace thermion
{

    using namespace filament;

    class GltfSceneAssetInstance : public SceneAsset
    {
    public:
        GltfSceneAssetInstance(
            gltfio::FilamentInstance *instance,
            Engine *engine,
            utils::NameComponentManager* ncm,
            MaterialInstance **materialInstances = nullptr,
            size_t materialInstanceCount = 0,
            int instanceIndex = -1) : _ncm(ncm), 
                                      _instance(instance),
                                      _materialInstances(materialInstances),
                                      _materialInstanceCount(materialInstanceCount)
        {
        }

        ~GltfSceneAssetInstance();

        SceneAsset *createInstance(MaterialInstance **materialInstances = nullptr, size_t materialInstanceCount = 0) override
        {
            return std::nullptr_t();
        };

        SceneAssetType getType() override
        {
            return SceneAsset::SceneAssetType::Gltf;
        }

        bool isInstance() override
        {
            return true;
        }

        utils::Entity getEntity() override
        {
            return _instance->getRoot();
        }

        MaterialInstance **getMaterialInstances() override
        {
            return _materialInstances;
        }

        size_t getMaterialInstanceCount() override
        {
            return _materialInstanceCount;
        }

        gltfio::FilamentInstance *getInstance()
        {
            return _instance;
        }

        void addAllEntities(Scene *scene) override
        {
            scene->addEntities(_instance->getEntities(), _instance->getEntityCount());
        }

        void removeAllEntities(Scene *scene) override {
            scene->removeEntities(_instance->getEntities(), _instance->getEntityCount());
        }

        size_t getInstanceCount() override
        {
            return 0;
        }

        SceneAsset *getInstanceAt(size_t index) override
        {
            return std::nullptr_t();
        }

        size_t getChildEntityCount() override
        {
            return _instance->getEntityCount();
        }

        const Entity* getChildEntities() override {
            return _instance->getEntities();
        }

        Entity findEntityByName(const char* name) override { 
            
            TRACE("Searching for entity with name %s", name);

            for(int i = 0; i < getChildEntityCount(); i++) {
                auto entity = getChildEntities()[i];
                auto nameInstance = _ncm->getInstance(entity);
                auto entityName = _ncm->getName(nameInstance);

                if (strcmp(entityName, name) == 0) {
                    TRACE("Found entity name : %s", entityName);
                    return entity;
                }
                TRACE("Skipping entity : %s", entityName);

            }
            return Entity(); 
        }

        SceneAsset *getInstanceByEntity(utils::Entity entity) override {
            return std::nullptr_t();
        }

        void setPriority(RenderableManager &rm, int priority) override
        {
            const Entity *entities = _instance->getEntities();
            for (int i = 0; i < _instance->getEntityCount(); i++)
            {
                if (rm.hasComponent(entities[i]))
                {
                    auto renderableInstance = rm.getInstance(entities[i]);
                    rm.setPriority(renderableInstance, priority);
                }
            }
        }

        void setLayer(RenderableManager &rm, int layer) override
        {
            const Entity *entities = _instance->getEntities();
            for (int i = 0; i < _instance->getEntityCount(); i++)
            {
                if (rm.hasComponent(entities[i]))
                {
                    auto renderableInstance = rm.getInstance(entities[i]);
                    rm.setLayerMask(renderableInstance, 0xFF, 1u << (uint8_t)layer);
                }
            }
        }



    private:
        filament::Engine *_engine;
        utils::NameComponentManager *_ncm;
        gltfio::FilamentInstance *_instance;
        MaterialInstance **_materialInstances = nullptr;
        size_t _materialInstanceCount = 0;
    };

} // namespace thermion