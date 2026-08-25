#pragma once

#include <memory>
#include <unordered_map>
#include <vector>

#include "../c_api/APIBoundaryTypes.h"

#include <filament/BufferObject.h>
#include <filament/Engine.h>
#include <filament/MorphTargetBuffer.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/MaterialProvider.h>

#include <cgltf.h>

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

        /// Toggle between flat (per-face) and smooth (per-vertex) shading.
        /// Only valid after rebuildVertexBuffers() has been called.
        /// Swaps the TANGENTS buffer object on all preserved vertex buffers.
        void setFlatShading(bool flatShading);

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

        /// Returns the starting primitive offset for the given entity, or -1 if
        /// the entity has no preserved geometry (e.g., non-triangle primitives
        /// or no mesh match during rebuild).
        int getPrimitiveOffsetForEntity(utils::Entity entity) const;

        /// Returns the replacement MorphTargetBuffer for the given preserved
        /// slot, or nullptr when the slot has no morph replacement (no morph
        /// targets, or the entity was not eligible for a morph rebuild).
        MorphTargetBuffer *getPreservedMorphBuffer(size_t index) const {
            if (index < _preservedMorphInfos.size()) {
                return _preservedMorphInfos[index].mtb;
            }
            return nullptr;
        }

        size_t getBoneCount(size_t skinIndex) const override;
        const utils::Entity *getBones(size_t skinIndex) const override;
        const char *getBoneName(size_t skinIndex, size_t boneIndex) const override;

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
        bool _flatShading = false;

        // Buffers created by rebuildVertexBuffers, owned by this asset.
        std::vector<VertexBuffer*> _preservedVertexBuffers;
        std::vector<IndexBuffer*> _preservedIndexBuffers;
        std::vector<size_t> _preservedIndexCounts;
        std::vector<BufferObject*> _preservedBufferObjects;
        std::vector<BufferObject*> _smoothTangentBOs;
        std::vector<BufferObject*> _flatTangentBOs;

        // Morph-target replacement state, parallel to _preservedVertexBuffers.
        // rebuildVertexBuffers replaces indexed geometry with unwelded
        // geometry, so the gltfio-created MorphTargetBuffer (sized for the
        // original welded vertex count) no longer matches. Filament only
        // allows a MorphTargetBuffer to be attached at RenderableManager
        // build time, so affected renderables are rebuilt against a
        // replacement buffer holding the unwelded morph deltas.
        struct PreservedMorphInfo
        {
            MorphTargetBuffer *mtb = nullptr; // shared by all instances of this mesh
            size_t vertexOffset = 0;          // this primitive's offset within mtb
            size_t targetCount = 0;           // morph target count for this entity
            const cgltf_node *node = nullptr; // source node (skin + default weights)
        };
        std::vector<PreservedMorphInfo> _preservedMorphInfos;

        // Replacement MorphTargetBuffers created by rebuildVertexBuffers,
        // owned by this asset (one per rebuilt renderable entity).
        std::vector<MorphTargetBuffer *> _ownedMorphTargetBuffers;

        /// Rebuild the renderable component on @param entity against the
        /// preserved geometry slots starting at @param slotStart, preserving
        /// all renderable state (materials, shadows, bounding box, skinning,
        /// layer/priority) and attaching the replacement morph target buffer.
        /// Returns false (and does nothing) when any primitive in the entity's
        /// slot range lacks a morph replacement — callers then fall back to
        /// per-primitive setGeometryAt.
        bool rebuildRenderableWithMorphs(utils::Entity entity, size_t slotStart);

        // Map from entity ID to starting offset in _preservedVertexBuffers.
        // Built during rebuildVertexBuffers to enable O(1) lookup.
        // Uses EntityId (int32_t) instead of utils::Entity for hashability.
        std::unordered_map<EntityId, size_t> _entityToPrimitiveOffset;
    };

} // namespace thermion