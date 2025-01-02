#include <vector>

#include <gltfio/MaterialProvider.h>
#include <filament/Engine.h>
#include <filament/Frustum.h>
#include <filament/RenderableManager.h>
#include <filament/Texture.h>
#include <filament/TransformManager.h>
#include <filament/Viewport.h>
#include <filament/geometry/SurfaceOrientation.h>

#include "Log.hpp"
#include "scene/GeometrySceneAsset.hpp"
#include "scene/GeometrySceneAssetBuilder.hpp"

namespace thermion
{

    using namespace filament;

    GeometrySceneAsset::GeometrySceneAsset(
        Engine *engine,
        VertexBuffer *vertexBuffer,
        IndexBuffer *indexBuffer,
        MaterialInstance **materialInstances,
        size_t materialInstanceCount,
        RenderableManager::PrimitiveType primitiveType,
        Box boundingBox,
        GeometrySceneAsset *instanceOwner)
        : _engine(engine), _vertexBuffer(vertexBuffer), _indexBuffer(indexBuffer), _materialInstances(materialInstances), _materialInstanceCount(materialInstanceCount), _primitiveType(primitiveType), _boundingBox(boundingBox), _instanceOwner(instanceOwner)
    {
        _entity = utils::EntityManager::get().create();

        RenderableManager::Builder builder(1);
        builder.boundingBox(_boundingBox)
            .geometry(0, _primitiveType, _vertexBuffer, _indexBuffer)
            .culling(true)
            .receiveShadows(true)
            .castShadows(true);
        for (int i = 0; i < materialInstanceCount; i++)
        {
            builder.material(i, materialInstances[i]);
        }
        builder.build(*_engine, _entity);
    }

    GeometrySceneAsset::~GeometrySceneAsset()
    {
        if (_engine)
        {
            if (_vertexBuffer && !isInstance())
                _engine->destroy(_vertexBuffer);
            if (_indexBuffer && !isInstance())
                _engine->destroy(_indexBuffer);
        }
    }

    SceneAsset *GeometrySceneAsset::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {
        if (isInstance())
        {
            Log("Cannot create an instance from another instance. Ensure you are calling createInstance with the original asset.");
            return nullptr;
        }

        std::unique_ptr<GeometrySceneAsset> instance = std::make_unique<GeometrySceneAsset>(
            _engine,
            _vertexBuffer,
            _indexBuffer,
            materialInstances,
            materialInstanceCount,
            _primitiveType,
            _boundingBox,
            this);
        auto *raw = instance.get();
        _instances.push_back(std::move(instance));
        return raw;
    }

    void GeometrySceneAsset::destroyInstance(SceneAsset *asset)
    {
        auto it = std::remove_if(_instances.begin(), _instances.end(), [=](auto &sceneAsset)
                                 { return sceneAsset.get() == asset; });
        _instances.erase(it, _instances.end());
    }

} // namespace thermion