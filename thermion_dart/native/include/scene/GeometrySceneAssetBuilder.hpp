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
        GeometrySceneAssetBuilder(filament::Engine *engine) : mEngine(engine) {}

        GeometrySceneAssetBuilder &vertices(const float *vertices, uint32_t count)
        {
            mVertices->resize(count);
            std::copy(vertices, vertices + count, mVertices->data());
            mNumVertices = count;
            return *this;
        }

        GeometrySceneAssetBuilder &normals(const float *normals, uint32_t count)
        {
            if (normals)
            {
                mNormals->resize(count);
                std::copy(normals, normals + count, mNormals->data());
            }
            else
            {
                mNormals->clear();
            }
            mNumNormals = count;
            return *this;
        }

        GeometrySceneAssetBuilder &uvs(const float *uvs, uint32_t count)
        {
            if (uvs)
            {
                mUVs->resize(count);
                std::copy(uvs, uvs + count, mUVs->data());
            }
            else
            {
                mUVs->clear();
            }
            mNumUVs = count;
            return *this;
        }

        GeometrySceneAssetBuilder &indices(const uint16_t *indices, uint32_t count)
        {
            mIndices->resize(count);
            std::copy(indices, indices + count, mIndices->data());
            mNumIndices = count;
            return *this;
        }

        GeometrySceneAssetBuilder &materials(filament::MaterialInstance **materials, size_t materialInstanceCount)
        {
            mMaterialInstances = materials;
            mMaterialInstanceCount = materialInstanceCount;
            return *this;
        }

        GeometrySceneAssetBuilder &primitiveType(filament::RenderableManager::PrimitiveType type)
        {
            mPrimitiveType = type;
            return *this;
        }

        std::unique_ptr<GeometrySceneAsset> build()
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

            Log("Creating entity...");
            auto entity = utils::EntityManager::get().create();
            Log("Entity created: %d", entity.getId());

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

    private:
        Box computeBoundingBox()
        {
            float minX = FLT_MAX, minY = FLT_MAX, minZ = FLT_MAX;
            float maxX = -FLT_MAX, maxY = -FLT_MAX, maxZ = -FLT_MAX;
            Box box;
            for (uint32_t i = 0; i < mNumVertices; i += 3)
            {
                minX = std::min(mVertices->at(i), minX);
                minY = std::min(mVertices->at(i + 1), minY);
                minZ = std::min(mVertices->at(i + 2), minZ);
                maxX = std::max(mVertices->at(i), maxX);
                maxY = std::max(mVertices->at(i + 1), maxY);
                maxZ = std::max(mVertices->at(i + 2), maxZ);
            }
            const filament::math::float3 min {minX, minY, minZ};
            const filament::math::float3 max {maxX, maxY, maxZ};
            box.set(min, max);
            return box;
        }

        std::pair<filament::VertexBuffer *, filament::IndexBuffer *> createBuffers()
        {
            auto indexBuffer = IndexBuffer::Builder()
                                   .indexCount(mNumIndices)
                                   .bufferType(IndexBuffer::IndexType::USHORT)
                                   .build(*mEngine);

            indexBuffer->setBuffer(*mEngine,
                                   IndexBuffer::BufferDescriptor(
                                       mIndices->data(),
                                       mNumIndices * sizeof(uint16_t),
                                       [](void *, size_t, void *data)
                                       {
                                           delete static_cast<std::vector<float> *>(data);
                                       },
                                       mIndices));

            if (mUVs->empty())
            {
                mUVs->resize(mNumVertices);
                std::fill(mUVs->begin(), mUVs->end(), 0.0f);
            }

            auto dummyColors = new std::vector<filament::math::float4>(
                mNumVertices, filament::math::float4{1.0f, 1.0f, 1.0f, 1.0f});

            auto vertexBufferBuilder =
                VertexBuffer::Builder()
                    .vertexCount(mNumVertices)
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
                                          mVertices->data(), mNumVertices * sizeof(float),
                                          [](void *, size_t, void *) {}));

            vertexBuffer->setBufferAt(*mEngine, 1,
                                      VertexBuffer::BufferDescriptor(
                                          mUVs->data(), mUVs->size() * sizeof(float),
                                          [](void *, size_t, void *data)
                                          {
                                          },
                                          mUVs));

            vertexBuffer->setBufferAt(*mEngine, 2,
                                      VertexBuffer::BufferDescriptor(
                                          mUVs->data(), mUVs->size() * sizeof(float),
                                          [](void *, size_t, void *data) {
                                              delete static_cast<std::vector<float> *>(data);

                                          },
                                          mUVs));

            vertexBuffer->setBufferAt(*mEngine, 3,
                                      VertexBuffer::BufferDescriptor(
                                          dummyColors->data(), dummyColors->size() * sizeof(math::float4),
                                          [](void *, size_t, void *data)
                                          {
                                              delete static_cast<std::vector<math::float4> *>(data);
                                          },
                                          dummyColors));

            if (!mNormals->empty())
            {
                assert(mPrimitiveType == RenderableManager::PrimitiveType::TRIANGLES);

                std::vector<filament::math::ushort3> triangles;
                for (uint32_t i = 0; i < mNumIndices; i += 3)
                {
                    triangles.push_back({mIndices->at(i),
                                         mIndices->at(i + 1),
                                         mIndices->at(i + 2)});
                }

                auto &builder = geometry::SurfaceOrientation::Builder()
                                    .vertexCount(mNumVertices)
                                    .normals((filament::math::float3 *)mNormals->data())
                                    .positions((filament::math::float3 *)mVertices->data())
                                    .triangleCount(triangles.size())
                                    .triangles(triangles.data());

                auto orientation = builder.build();
                auto quats = new std::vector<filament::math::quatf>(mNumVertices);
                orientation->getQuats(quats->data(), mNumVertices);

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

        bool validate() const
        {
            if (!mEngine)
            {
                Log("Validation failed: No engine");
                return false;
            }
            if (mVertices->empty() || mNumVertices == 0)
            {
                Log("Validation failed: No vertices (empty=%d, count=%d)", mVertices->empty(), mNumVertices);
                return false;
            }
            if (mNumNormals > 0 && !mNormals->empty() && mNumNormals != mNumVertices)
            {
                Log("Validation failed: Normal count mismatch (normals=%d, vertices=%d)", mNumNormals, mNumVertices);
                return false;
            }
            if (mNumUVs > 0 && !mUVs->empty() && mNumUVs != mNumVertices)
            {
                Log("Validation failed: UV count mismatch (uvs=%d, vertices=%d)", mNumUVs, mNumVertices);
                return false;
            }
            if (mIndices->empty() || mNumIndices == 0)
            {
                Log("Validation failed: No indices (empty=%d, count=%d)", mIndices->empty(), mNumIndices);
                return false;
            }

            Log("Validation passed: vertices=%d, normals=%s, uvs=%d, indices=%d",
                mNumVertices,
                (!mNormals->empty() ? "yes" : "no"),
                mNumUVs,
                mNumIndices);
            return true;
        }

        filament::Engine *mEngine = nullptr;
        std::vector<float> *mVertices = new std::vector<float>();
        std::vector<float> *mNormals = new std::vector<float>();
        std::vector<float> *mUVs = new std::vector<float>();
        std::vector<uint16_t> *mIndices = new std::vector<uint16_t>;
        uint32_t mNumVertices = 0;
        uint32_t mNumNormals = 0;
        uint32_t mNumUVs = 0;
        uint32_t mNumIndices = 0;
        filament::MaterialInstance **mMaterialInstances = nullptr;
        size_t mMaterialInstanceCount = 0;
        filament::gltfio::MaterialProvider *mMaterialProvider = nullptr;
        filament::RenderableManager::PrimitiveType mPrimitiveType =
            filament::RenderableManager::PrimitiveType::TRIANGLES;
    };

} // namespace thermion