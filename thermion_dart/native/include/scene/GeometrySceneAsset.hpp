#pragma once

#include <memory>
#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <gltfio/MaterialProvider.h>
#include "scene/SceneAsset.hpp"

namespace thermion
{

    using namespace filament;

    class GeometrySceneAsset : public SceneAsset
    {
    public:
        GeometrySceneAsset(bool isInstance,
                           Engine *engine,
                           VertexBuffer *vertexBuffer,
                           IndexBuffer *indexBuffer,
                           MaterialInstance **materialInstances,
                           size_t materialInstanceCount,
                           RenderableManager::PrimitiveType primitiveType,
                           Box boundingBox);
        ~GeometrySceneAsset();

        SceneAsset *createInstance(MaterialInstance **materialInstances = nullptr, size_t materialInstanceCount = 0) override;

        SceneAssetType getType() override
        {
            return SceneAsset::SceneAssetType::Geometry;
        }

        bool isInstance() override
        {
            return _isInstance;
        }

        utils::Entity getEntity() override
        {
            return _entity;
        }

        MaterialInstance **getMaterialInstances() override
        {
            return _materialInstances;
        }

        size_t getMaterialInstanceCount() override
        {
            return _materialInstanceCount;
        }

        const Aabb getBoundingBox() const override
        {
            return Aabb {

                .min = _boundingBox.getMin(), // center - halfExtent
                .max = _boundingBox.getMax()  // center + halfExtent
            };
        }
        VertexBuffer *getVertexBuffer() const { return _vertexBuffer; }
        IndexBuffer *getIndexBuffer() const { return _indexBuffer; }

        void addAllEntities(Scene *scene) override
        {
            scene->addEntity(_entity);
        }

        void removeAllEntities(Scene *scene) override
        {
            scene->remove(_entity);
        }

        void setPriority(RenderableManager &rm, int priority) override
        {
            auto renderableInstance = rm.getInstance(_entity);
            rm.setPriority(renderableInstance, priority);
        }

        void setLayer(RenderableManager &rm, int layer) override
        {
            auto renderableInstance = rm.getInstance(_entity);
            rm.setLayerMask(renderableInstance, 0xFF, 1u << (uint8_t)layer);
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
            return 0;
        }

        const Entity *getChildEntities() override
        {
            return nullptr;
        }

        Entity findEntityByName(const char *name) override
        {
            return Entity(); // not currently implemented
        }

        static std::unique_ptr<GeometrySceneAsset> create(
            float *vertices, uint32_t numVertices,
            float *normals, uint32_t numNormals,
            float *uvs, uint32_t numUvs,
            uint16_t *indices, uint32_t numIndices,
            MaterialInstance *materialInstance,
            RenderableManager::PrimitiveType primitiveType,
            Engine *engine);

    private:
        Engine *_engine = nullptr;
        VertexBuffer *_vertexBuffer = nullptr;
        IndexBuffer *_indexBuffer = nullptr;
        MaterialInstance **_materialInstances = nullptr;
        size_t _materialInstanceCount = 0;
        Box _boundingBox;
        bool _isInstance = false;
        utils::Entity _entity;
        RenderableManager::PrimitiveType _primitiveType;
        std::vector<std::unique_ptr<GeometrySceneAsset>> _instances;
    };

} // namespace thermion