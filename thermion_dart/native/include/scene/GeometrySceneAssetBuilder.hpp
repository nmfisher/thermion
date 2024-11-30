#pragma once

#include <memory>
#include <vector>
#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/geometry/SurfaceOrientation.h>
#include <filament/Box.h>
#include <gltfio/MaterialProvider.h>
#include "GeometrySceneAsset.hpp"
#include "Log.hpp"

namespace thermion
{
    class GeometrySceneAssetBuilder
    {
    public:
        GeometrySceneAssetBuilder(filament::Engine *engine);

        GeometrySceneAssetBuilder &vertices(const float *vertices, uint32_t count);
        
        GeometrySceneAssetBuilder &normals(const float *normals, uint32_t count);
        
        GeometrySceneAssetBuilder &uvs(const float *uvs, uint32_t count);
        

        GeometrySceneAssetBuilder &indices(const uint16_t *indices, uint32_t count);
        
        GeometrySceneAssetBuilder &materials(filament::MaterialInstance **materials, size_t materialInstanceCount);
        
        GeometrySceneAssetBuilder &primitiveType(filament::RenderableManager::PrimitiveType type);
        
        std::unique_ptr<GeometrySceneAsset> build();
        
    private:
        Box computeBoundingBox();
        
        std::pair<filament::VertexBuffer *, filament::IndexBuffer *> createBuffers();
        

        bool validate() const;

        filament::Engine *mEngine = nullptr;
        std::vector<filament::math::float3> *mVertices = new std::vector<filament::math::float3>();
        std::vector<filament::math::float3> *mNormals = new std::vector<filament::math::float3>();
        std::vector<filament::math::float2> *mUVs = new std::vector<filament::math::float2>();
        std::vector<uint16_t> *mIndices = new std::vector<uint16_t>;
        filament::MaterialInstance **mMaterialInstances = nullptr;
        size_t mMaterialInstanceCount = 0;
        filament::gltfio::MaterialProvider *mMaterialProvider = nullptr;
        filament::RenderableManager::PrimitiveType mPrimitiveType =
            filament::RenderableManager::PrimitiveType::TRIANGLES;
    };

} // namespace thermion