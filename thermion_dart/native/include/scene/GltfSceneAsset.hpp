#pragma once

#include <memory>
#include <vector>

#include <filament/BufferObject.h>
#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/MaterialProvider.h>

#include <utils/NameComponentManager.h>

#include "scene/GltfSceneAssetInstance.hpp"

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
            utils::NameComponentManager* ncm,
            bool rebuildVertices = false,
            MaterialInstance **materialInstances = nullptr,
            size_t materialInstanceCount = 0);

        ~GltfSceneAsset();

        SceneAsset *createInstance(MaterialInstance **materialInstances = nullptr, size_t materialInstanceCount = 0) override;

        /// @brief 
        /// @param asset the instance to be destroyed
        ///
        /// Note that instances are not actually destroyed until the parent asset is destroyed. 
        /// When this method is called, @param asset will be marked as inactive 
        /// and recycled whenever createInstance is called again.
        void destroyInstance(SceneAsset *asset) override;

        SceneAssetType getType() override
        {
            return SceneAsset::SceneAssetType::Gltf;
        }

        bool isInstance() override
        {
            return false;
        }

        SceneAsset *getInstanceOwner() override { 
            return std::nullptr_t();
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
            auto found = _asset->getEntitiesByName(name, entities, 1);
            return entities[0];
        }

        const filament::Aabb getBoundingBox() const override {
            return _asset->getBoundingBox();
        }

        /// Rebuild all mesh primitives with a superset vertex buffer layout
        /// (POSITION + TANGENTS + UV0 + CUSTOM0 + optional BONE_INDICES/WEIGHTS).
        /// Unwelds vertices so each triangle has unique vertices for barycentric
        /// wireframe rendering. After this, materials can be freely swapped via
        /// setMaterialInstanceAt. Requires source data to still be available.
        void rebuildVertexBuffers();

        /// Release the underlying cgltf source data early to free memory.
        /// Safe to call multiple times; subsequent calls are no-ops.
        void releaseSourceData();

        bool geometryPreserved() const { return _geometryPreserved; }

        /// Returns the preserved vertex buffer at the given index, or nullptr.
        VertexBuffer* getPreservedVertexBuffer(size_t index) const {
            if (index < _preservedVertexBuffers.size()) {
                return _preservedVertexBuffers[index];
            }
            return nullptr;
        }

        /// Returns the preserved index buffer at the given index, or nullptr.
        IndexBuffer* getPreservedIndexBuffer(size_t index) const {
            if (index < _preservedIndexBuffers.size()) {
                return _preservedIndexBuffers[index];
            }
            return nullptr;
        }

        /// Returns the number of preserved vertex buffers.
        size_t getPreservedVertexBufferCount() const {
            return _preservedVertexBuffers.size();
        }

    private:
        gltfio::FilamentAsset *_asset;
        gltfio::AssetLoader *_assetLoader;
        Engine *_engine;
        utils::NameComponentManager *_ncm;
        MaterialInstance **_materialInstances = nullptr;
        size_t _materialInstanceCount = 0;
        std::vector<std::unique_ptr<GltfSceneAssetInstance>> _instances;

        bool _sourceDataReleased = false;
        bool _geometryPreserved = false;

        // Buffers created by rebuildVertexBuffers, owned by this asset.
        std::vector<VertexBuffer*> _preservedVertexBuffers;
        std::vector<IndexBuffer*> _preservedIndexBuffers;
        std::vector<size_t> _preservedIndexCounts;
        std::vector<BufferObject*> _preservedBufferObjects;
    };

} // namespace thermion