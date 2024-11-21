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
        bool isInstance,
        Engine *engine,
        VertexBuffer *vertexBuffer,
        IndexBuffer *indexBuffer,
        MaterialInstance **materialInstances,
        size_t materialInstanceCount,
        RenderableManager::PrimitiveType primitiveType,
        Box boundingBox)
        : _isInstance(isInstance),
          _engine(engine), _vertexBuffer(vertexBuffer), _indexBuffer(indexBuffer), _materialInstances(materialInstances), _materialInstanceCount(materialInstanceCount), _primitiveType(primitiveType), _boundingBox(boundingBox)
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
            if (_vertexBuffer && !_isInstance)
                _engine->destroy(_vertexBuffer);
            if (_indexBuffer && !_isInstance)
                _engine->destroy(_indexBuffer);
        }
    }

    SceneAsset *GeometrySceneAsset::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {
        if (_isInstance)
        {
            Log("Cannot create an instance from another instance. Ensure you are calling createInstance with the original asset.");
            return nullptr;
        }

        std::unique_ptr<GeometrySceneAsset> instance = std::make_unique<GeometrySceneAsset>(
            true,
            _engine,
            _vertexBuffer,
            _indexBuffer,
            materialInstances,
            materialInstanceCount,
            _primitiveType,
            _boundingBox);
        auto *raw = instance.get();
        _instances.push_back(std::move(instance));
        return raw;
    }

    // std::unique_ptr<GeometrySceneAsset> GeometrySceneAsset::create(
    //     float *vertices, uint32_t numVertices,
    //     float *normals, uint32_t numNormals,
    //     float *uvs, uint32_t numUvs,
    //     uint16_t *indices, uint32_t numIndices,
    //     MaterialInstance **materialInstances,
    //     size_t materialInstanceCount,
    //     RenderableManager::PrimitiveType primitiveType,
    //     Engine *engine)
    // {

    // // Setup texture if needed
    // if (asset && uvs && numUvs > 0 &&
    //     asset->getMaterialInstance() &&
    //     asset->getMaterialInstance()->getMaterial()->hasParameter("baseColorMap"))
    // {
    //     static constexpr uint32_t textureSize = 1;
    //     static constexpr uint32_t white = 0x00ffffff;

    //     auto texture = Texture::Builder()
    //                        .width(textureSize)
    //                        .height(textureSize)
    //                        .levels(1)
    //                        .format(Texture::InternalFormat::RGBA8)
    //                        .build(*engine);

    //     filament::backend::PixelBufferDescriptor pbd(
    //         &white, 4, Texture::Format::RGBA, Texture::Type::UBYTE);
    //     texture->setImage(*engine, 0, std::move(pbd));

    //     TextureSampler sampler(
    //         TextureSampler::MinFilter::NEAREST,
    //         TextureSampler::MagFilter::NEAREST);
    //     sampler.setWrapModeS(TextureSampler::WrapMode::REPEAT);
    //     sampler.setWrapModeT(TextureSampler::WrapMode::REPEAT);

    //     asset->getMaterialInstance()->setParameter("baseColorMap", texture, sampler);
    // }

    // return asset;
    // }

} // namespace thermion