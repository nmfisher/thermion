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

#include "scene/GeometrySceneAssetBuilder.hpp"
#include "scene/GeometrySceneAsset.hpp"
#include "Log.hpp"

namespace thermion
{
    GeometrySceneAssetBuilder::GeometrySceneAssetBuilder(filament::Engine *engine) : mEngine(engine)
    {
    }

    GeometrySceneAssetBuilder &GeometrySceneAssetBuilder::vertices(const float *vertices, uint32_t count)
    {
        if (count > 0)
        {
            mVertices->resize(count / 3);
            for (int i = 0; i < mVertices->size(); i++)
            {
                mVertices->at(i) = filament::math::float3{vertices[(i * 3)], vertices[(i * 3) + 1], vertices[(i * 3) + 2]};
            }
        }
        return *this;
    }

    GeometrySceneAssetBuilder &GeometrySceneAssetBuilder::normals(const float *normals, uint32_t count)
    {
        if (count > 0)
        {
            mNormals->resize(count / 3);
            for (int i = 0; i < mNormals->size(); i++)
            {
                mNormals->at(i) = filament::math::float3{normals[i * 3], normals[(i * 3) + 1], normals[(i * 3) + 2]};
            }
        }
        return *this;
    }

    GeometrySceneAssetBuilder &GeometrySceneAssetBuilder::uvs(const float *uvs, uint32_t count)
    {
        if (count > 0)
        {
            mUVs->resize(count / 2);
            for (int i = 0; i < mUVs->size(); i++)
            {
                mUVs->at(i) = filament::math::float2{uvs[i * 2], uvs[(i * 2) + 1]};
            }
        }
        return *this;
    }

    GeometrySceneAssetBuilder &GeometrySceneAssetBuilder::indices(const uint16_t *indices, uint32_t count)
    {
        if (count > 0)
        {
            mIndices->resize(count);
            for (int i = 0; i < mIndices->size(); i++)
            {
                mIndices->at(i) = indices[i];
            }
        }
        return *this;
    }

    GeometrySceneAssetBuilder &GeometrySceneAssetBuilder::materials(filament::MaterialInstance **materials, size_t materialInstanceCount)
    {
        mMaterialInstances = materials;
        mMaterialInstanceCount = materialInstanceCount;
        return *this;
    }

    GeometrySceneAssetBuilder &GeometrySceneAssetBuilder::primitiveType(filament::RenderableManager::PrimitiveType type)
    {
        mPrimitiveType = type;
        return *this;
    }

    std::unique_ptr<GeometrySceneAsset> GeometrySceneAssetBuilder::build()
    {
        Log("Starting build. Validating inputs...");
        if (!validate())
        {
            Log("Validation failed!");
            return nullptr;
        }

        Log("Creating buffers...");
        auto [vertexBuffer, indexBuffer] = createBuffers();
        if (!vertexBuffer || !indexBuffer)
        {
            Log("Failed to create buffers: VB=%p, IB=%p", vertexBuffer, indexBuffer);
            return nullptr;
        }
        Log("Buffers created successfully: VB=%p, IB=%p", vertexBuffer, indexBuffer);

        Box boundingBox = computeBoundingBox();
        Log("Computed bounding box: min={%f,%f,%f}, max={%f,%f,%f}",
            boundingBox.getMin().x, boundingBox.getMin().y, boundingBox.getMin().z,
            boundingBox.getMax().x, boundingBox.getMax().y, boundingBox.getMax().z);

        auto asset = std::make_unique<GeometrySceneAsset>(
            false,
            mEngine,
            vertexBuffer,
            indexBuffer,
            mMaterialInstances,
            mMaterialInstanceCount,
            mPrimitiveType,
            boundingBox);

        Log("Asset created: %p", asset.get());
        return asset;
    }

    Box GeometrySceneAssetBuilder::computeBoundingBox()
    {
        float minX = FLT_MAX, minY = FLT_MAX, minZ = FLT_MAX;
        float maxX = -FLT_MAX, maxY = -FLT_MAX, maxZ = -FLT_MAX;
        Box box;
        for (auto &vertex : *mVertices)
        {
            minX = std::min(vertex.x, minX);
            minY = std::min(vertex.y, minY);
            minZ = std::min(vertex.z, minZ);
            maxX = std::max(vertex.x, maxX);
            maxY = std::max(vertex.y, maxY);
            maxZ = std::max(vertex.z, maxZ);
        }
        const filament::math::float3 min{minX, minY, minZ};
        const filament::math::float3 max{maxX, maxY, maxZ};
        box.set(min, max);
        return box;
    }

    std::pair<filament::VertexBuffer *, filament::IndexBuffer *> GeometrySceneAssetBuilder::createBuffers()
    {
        auto indexBuffer = IndexBuffer::Builder()
                               .indexCount(mIndices->size())
                               .bufferType(IndexBuffer::IndexType::USHORT)
                               .build(*mEngine);

        indexBuffer->setBuffer(*mEngine,
                               IndexBuffer::BufferDescriptor(
                                   mIndices->data(),
                                   mIndices->size() * sizeof(uint16_t),
                                   [](void *, size_t, void *data)
                                   {
                                       delete static_cast<std::vector<uint16_t> *>(data);
                                   },
                                   mIndices));

        if (mUVs->empty())
        {
            mUVs->resize(mVertices->size());
            std::fill(mUVs->begin(), mUVs->end(), filament::math::float2{0.0f, 0.0f});
        }

        auto vertexBufferBuilder =
            VertexBuffer::Builder()
                .vertexCount(mVertices->size())
                .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                .attribute(VertexAttribute::UV0, 1, VertexBuffer::AttributeType::FLOAT2)
                .attribute(VertexAttribute::UV1, 2, VertexBuffer::AttributeType::FLOAT2)
                .attribute(VertexAttribute::COLOR, 3, VertexBuffer::AttributeType::FLOAT4);

        if (!mNormals->empty())
        {
            vertexBufferBuilder.bufferCount(5)
                .attribute(VertexAttribute::TANGENTS, 4, VertexBuffer::AttributeType::FLOAT4);
        }
        else
        {
            vertexBufferBuilder = vertexBufferBuilder.bufferCount(4);
        }

        auto vertexBuffer = vertexBufferBuilder.build(*mEngine);

        vertexBuffer->setBufferAt(*mEngine, 0,
                                  VertexBuffer::BufferDescriptor(
                                      mVertices->data(), mVertices->size() * sizeof(filament::math::float3),
                                      [](void *, size_t, void *) {

                                      }));

        vertexBuffer->setBufferAt(*mEngine, 1,
                                  VertexBuffer::BufferDescriptor(
                                      mUVs->data(), mUVs->size() * sizeof(filament::math::float2),
                                      [](void *, size_t, void *data) {

                                      },
                                      mUVs));

        vertexBuffer->setBufferAt(*mEngine, 2,
                                  VertexBuffer::BufferDescriptor(
                                      mUVs->data(), mUVs->size() * sizeof(filament::math::float2),
                                      [](void *, size_t, void *data)
                                      {
                                          delete static_cast<std::vector<filament::math::float2> *>(data);
                                      },
                                      mUVs));

        auto dummyColors = new std::vector<filament::math::float4>(
            mVertices->size(), filament::math::float4{1.0f, 1.0f, 1.0f, 1.0f});
        vertexBuffer->setBufferAt(*mEngine, 3,
                                  VertexBuffer::BufferDescriptor(
                                      dummyColors->data(), dummyColors->size() * sizeof(math::float4),
                                      [](void *, size_t, void *data)
                                      {
                                          delete static_cast<std::vector<math::float4> *>(data);
                                      },
                                      dummyColors));
        if (mNormals->size() > 0)
        {

            std::vector<filament::math::ushort3> triangles;

            for (uint32_t i = 0; i < mIndices->size(); i += 3)
            {
                triangles.push_back({mIndices->at(i),
                                     mIndices->at(i + 1),
                                     mIndices->at(i + 2)});
            }

            geometry::SurfaceOrientation::Builder builder;
            builder.vertexCount(mVertices->size());
            builder.normals(mNormals->data());
            builder.positions(mVertices->data());
            builder.triangleCount(triangles.size());
            builder.triangles(triangles.data());

            auto orientation = builder.build();
            auto quats = new std::vector<filament::math::quatf>(mVertices->size());
            orientation->getQuats(quats->data(), mVertices->size());

            vertexBuffer->setBufferAt(*mEngine, 4,
                                      VertexBuffer::BufferDescriptor(
                                          quats->data(), quats->size() * sizeof(math::quatf),
                                          [](void *, size_t, void *data)
                                          {
                                              delete static_cast<std::vector<math::quatf> *>(data);
                                          },
                                          quats));
        }

        return {vertexBuffer, indexBuffer};
    }

    bool GeometrySceneAssetBuilder::validate() const
    {
        if (!mEngine)
        {
            Log("Validation failed: No engine");
            return false;
        }
        if (mVertices->empty())
        {
            Log("Validation failed: No vertices (empty=%d, count=%d)", mVertices->empty(), mVertices->size());
            return false;
        }

        if (!mNormals->empty())
        {
            assert(mPrimitiveType == RenderableManager::PrimitiveType::TRIANGLES);
        }
        if (!mNormals->empty() && mNormals->size() != mVertices->size())
        {
            Log("Validation failed: Normal count mismatch (normals=%d, vertices=%d)", mNormals->size(), mVertices->size());
            return false;
        }
        if (!mUVs->empty() && mUVs->size() != mVertices->size() * 2)
        {
            Log("Validation failed: UV count mismatch (uvs=%d, vertices=%d)", mUVs->size(), mVertices->size());
            return false;
        }
        if (mIndices->empty())
        {
            Log("Validation failed: No indices (empty=%d, count=%d)", mIndices->empty(), mIndices->size());
            return false;
        }

        Log("Validation passed: vertices=%d, normals=%s, uvs=%d, indices=%d",
            mVertices->size(),
            (!mNormals->empty() ? "yes" : "no"),
            mUVs->size(),
            mIndices->size());
        return true;
    }

} // namespace thermion