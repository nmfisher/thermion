#pragma once

#include <memory>
#include <vector>

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/MaterialProvider.h>

#include "scene/GltfSceneAssetInstance.hpp"
#include "components/AnimationComponentManager.hpp"
#include "components/CollisionComponentManager.hpp"

#include "scene/SceneAsset.hpp"

namespace thermion
{

    using namespace filament;

    class GltfSceneAsset : public SceneAsset
    {
    public:
        GltfSceneAsset(
            gltfio::FilamentAsset *asset,
            gltfio::AssetLoader *assetLoader,
            Engine *engine,
            MaterialInstance **materialInstances = nullptr,
            size_t materialInstanceCount = 0,
            int instanceIndex = -1) : _asset(asset),
                                      _assetLoader(assetLoader),
                                      _engine(engine),
                                      _materialInstances(materialInstances),
                                      _materialInstanceCount(materialInstanceCount)
        {
        }

        ~GltfSceneAsset();

        SceneAsset *createInstance(MaterialInstance **materialInstances = nullptr, size_t materialInstanceCount = 0) override;

        SceneAssetType getType() override
        {
            return SceneAsset::SceneAssetType::Gltf;
        }

        bool isInstance() override
        {
            return false;
        }

        utils::Entity getEntity() override
        {
            return _asset->getRoot();
        }

        MaterialInstance **getMaterialInstances() override
        {
            return _materialInstances;
        }

        size_t getMaterialInstanceCount() override
        {
            return _materialInstanceCount;
        }

        gltfio::FilamentAsset *getAsset()
        {
            return _asset;
        }

        void addAllEntities(Scene *scene) override
        {
            scene->addEntities(_asset->getEntities(), _asset->getEntityCount());
            scene->addEntities(_asset->getLightEntities(), _asset->getLightEntityCount());
            scene->addEntities(_asset->getCameraEntities(), _asset->getCameraEntityCount());
        }

        void removeAllEntities(Scene *scene) override
        {
            scene->removeEntities(_asset->getEntities(), _asset->getEntityCount());
            scene->removeEntities(_asset->getLightEntities(), _asset->getLightEntityCount());
            scene->removeEntities(_asset->getCameraEntities(), _asset->getCameraEntityCount());
        }

        void setPriority(RenderableManager &rm, int priority) override
        {
            const Entity *entities = _asset->getEntities();
            for (int i = 0; i < _asset->getEntityCount(); i++)
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
            const Entity *entities = _asset->getEntities();
            for (int i = 0; i < _asset->getEntityCount(); i++)
            {
                if (rm.hasComponent(entities[i]))
                {
                    auto renderableInstance = rm.getInstance(entities[i]);
                    rm.setLayerMask(renderableInstance, 0xFF, 1u << (uint8_t)layer);
                }
            }
        }

        SceneAsset *getInstanceByEntity(utils::Entity entity) override
        {
            for (auto &instance : _instances)
            {
                if (instance->getEntity() == entity)
                {
                    return instance.get();
                }
            }
            return std::nullptr_t();
        }

        SceneAsset *getInstanceAt(size_t index) override
        {
            auto &asset = _instances[index];
            return asset.get();
        }

        size_t getInstanceCount() override
        {
            return _instances.size();
        }

        size_t getChildEntityCount() override
        {
            return _asset->getEntityCount();
        }

        const Entity* getChildEntities() override { 
            return _asset->getEntities();
        }

        Entity findEntityByName(const char* name) override { 
            Entity entities[1];
            auto found =  _asset->getEntitiesByName(name, entities, 1);
            return entities[0];
        }

    private:
        gltfio::FilamentAsset *_asset;
        gltfio::AssetLoader *_assetLoader;
        Engine *_engine;
        MaterialInstance **_materialInstances = nullptr;
        size_t _materialInstanceCount = 0;
        std::vector<std::unique_ptr<GltfSceneAssetInstance>> _instances;
    };

} // namespace thermion