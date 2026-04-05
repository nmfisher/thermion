
#include "scene/GltfSceneAsset.hpp"
#include "scene/GltfSceneAssetInstance.hpp"
#include "gltfio/FilamentInstance.h"
#include "Log.hpp"

#include <memory>
#include <vector>
#include <cstdlib>
#include <cstring>

#include <filament/BufferObject.h>
#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/Animator.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/MaterialProvider.h>

#include <cgltf.h>

#include <filament/geometry/SurfaceOrientation.h>

#include <utils/NameComponentManager.h>

#include "scene/GltfSceneAssetInstance.hpp"
#include "scene/SceneAsset.hpp"

namespace thermion
{

    GltfSceneAsset::GltfSceneAsset(
        gltfio::FilamentAsset *asset,
        gltfio::AssetLoader *assetLoader,
        Engine *engine,
        utils::NameComponentManager *ncm,
        MaterialInstance **materialInstances,
        size_t materialInstanceCount) : _asset(asset),
                                        _assetLoader(assetLoader),
                                        _engine(engine),
                                        _ncm(ncm),
                                        _materialInstances(materialInstances),
                                        _materialInstanceCount(materialInstanceCount)
    {
        for (int i = 0; i < asset->getAssetInstanceCount(); i++)
        {
            createInstance();
        }
        TRACE("Created GltfSceneAsset from FilamentAsset %d with %d reserved instances", asset, asset->getAssetInstanceCount());
    }

    GltfSceneAsset::~GltfSceneAsset()
    {
        _instances.clear();
        for (auto *vb : _preservedVertexBuffers)
        {
            _engine->destroy(vb);
        }
        for (auto *ib : _preservedIndexBuffers)
        {
            _engine->destroy(ib);
        }
        for (auto *bo : _preservedBufferObjects)
        {
            _engine->destroy(bo);
        }
        releaseSourceData();
        _assetLoader->destroyAsset(_asset);
    }

    void GltfSceneAsset::releaseSourceData()
    {
        if (!_sourceDataReleased)
        {
            _asset->releaseSourceData();
            _sourceDataReleased = true;
        }
    }

    void GltfSceneAsset::destroyInstance(SceneAsset *asset)
    {
        for (auto &instance : _instances)
        {
            if (instance.get() == asset)
            {
                instance->inUse = false;
                return;
            }
        }
    };

    SceneAsset *GltfSceneAsset::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {

        // first, see if we can recycle any "unused" instances.
        for (auto &instance : _instances)
        {
            if (!instance->inUse)
            {
                instance->inUse = true;
                return instance.get();
            }
        }

        bool needsGeometryUpdate = false;
        if (_instances.size() == _asset->getAssetInstanceCount())
        {
            TRACE("Warning: %d pre-allocated instances already consumed. A new instance will be allocated internally, but in future you may wish to pre-allocate a larger number.",
                  _asset->getAssetInstanceCount());
            _assetLoader->createInstance(_asset);
            // Freshly-allocated instances reference the original vertex buffers,
            // which don't include barycentric coordinates. Apply preserved geometry.
            needsGeometryUpdate = _geometryPreserved;
        }
        else
        {
            TRACE("Returning pre-allocated instance at index %d", _instances.size());
        }

        auto instance = _asset->getAssetInstances()[_instances.size()];

        instance->recomputeBoundingBoxes();
        auto bb = instance->getBoundingBox();
        TRACE("Instance bounding box center (%f,%f,%f), extent (%f,%f,%f)", bb.center().x, bb.center().y, bb.center().z, bb.extent().x, bb.extent().y, bb.extent().z);
        instance->getAnimator()->updateBoneMatrices();

        auto &rm = _engine->getRenderableManager();

        if (materialInstanceCount > 0)
        {

            TRACE("Instance entity count : %d", instance->getEntityCount());

            for (int i = 0; i < instance->getEntityCount(); i++)
            {
                auto renderableInstance = rm.getInstance(instance->getEntities()[i]);
                if (!renderableInstance.isValid())
                {
                    TRACE("Instance child entity %d not renderable", i);
                }
                else
                {
                    TRACE("Instance child entity %d renderable", i);
                    for (int j = 0; j < materialInstanceCount; j++)
                    {
                        rm.setMaterialInstanceAt(renderableInstance, i, materialInstances[j]);
                    }
                }
            }
        }

        if (needsGeometryUpdate)
        {
            auto *instEntities = instance->getEntities();
            size_t instEntityCount = instance->getEntityCount();
            size_t totalBuffers = _preservedVertexBuffers.size();
            size_t bufferIndex = 0;
            for (size_t ei = 0; ei < instEntityCount && bufferIndex < totalBuffers; ei++)
            {
                auto instRi = rm.getInstance(instEntities[ei]);
                if (!instRi.isValid())
                    continue;
                size_t primCount = rm.getPrimitiveCount(instRi);
                for (size_t pi = 0; pi < primCount && bufferIndex < totalBuffers; pi++)
                {
                    rm.setGeometryAt(instRi, pi,
                                     RenderableManager::PrimitiveType::TRIANGLES,
                                     _preservedVertexBuffers[bufferIndex],
                                     _preservedIndexBuffers[bufferIndex],
                                     0, _preservedIndexCounts[bufferIndex]);
                    bufferIndex++;
                }
            }
            TRACE("createInstance: applied %zu preserved geometry buffers to new instance", bufferIndex);
        }

        std::unique_ptr<GltfSceneAssetInstance> sceneAssetInstance = std::make_unique<GltfSceneAssetInstance>(
            this,
            instance,
            _engine,
            _ncm,
            materialInstances,
            materialInstanceCount);

        auto *raw = sceneAssetInstance.get();

        _instances.push_back(std::move(sceneAssetInstance));
        return raw;
    }

    static const auto FREE_CB = [](void *mem, size_t, void *)
    { free(mem); };

    // Build a map from node/mesh name to cgltf_mesh for all nodes in the asset.
    // Multiple nodes can reference the same mesh, so we also build a flat list
    // of (name, mesh) pairs to handle unnamed nodes by index.
    struct MeshEntry
    {
        const char *name;     // node name (may be null)
        const char *meshName; // mesh name (may be null)
        const cgltf_mesh *mesh;
    };

    static void collectAllMeshEntries(const cgltf_data *data, std::vector<MeshEntry> &entries)
    {
        for (cgltf_size i = 0; i < data->nodes_count; i++)
        {
            const cgltf_node &node = data->nodes[i];
            if (node.mesh)
            {
                entries.push_back({node.name, node.mesh->name, node.mesh});
            }
        }
    }

    // Find the cgltf_mesh for a given renderable entity by matching names.
    static const cgltf_mesh *findMeshForEntity(
        utils::Entity entity,
        utils::NameComponentManager *ncm,
        const std::vector<MeshEntry> &meshEntries)
    {
        auto ni = ncm->getInstance(entity);
        if (!ni.isValid())
            return nullptr;

        auto entityName = ncm->getName(ni);
        if (!entityName || strlen(entityName) == 0)
            return nullptr;

        // Match against node name first, then mesh name
        for (const auto &entry : meshEntries)
        {
            if (entry.name && strcmp(entry.name, entityName) == 0)
            {
                return entry.mesh;
            }
            if (entry.meshName && strcmp(entry.meshName, entityName) == 0)
            {
                return entry.mesh;
            }
        }
        return nullptr;
    }

    void GltfSceneAsset::rebuildVertexBuffers()
    {
        auto *sourceData = (const cgltf_data *)_asset->getSourceAsset();
        if (!sourceData)
        {
            Log("rebuildVertexBuffers: source data already released");
            return;
        }

        if (_geometryPreserved)
        {
            Log("rebuildVertexBuffers: already called");
            return;
        }

        std::vector<MeshEntry> meshEntries;
        collectAllMeshEntries(sourceData, meshEntries);

        const auto *renderableEntities = _asset->getRenderableEntities();
        size_t renderableCount = _asset->getRenderableEntityCount();
        auto &rm = _engine->getRenderableManager();

        Log("rebuildVertexBuffers: meshEntries=%zu renderableEntities=%zu nodes=%zu",
            meshEntries.size(), renderableCount, sourceData->nodes_count);

        // Fallback index for entities without names: assign mesh entries
        // sequentially to renderable entities that fail name matching.
        size_t fallbackMeshIndex = 0;

        for (size_t ei = 0; ei < renderableCount; ei++)
        {
            auto entity = renderableEntities[ei];
            auto ri = rm.getInstance(entity);
            if (!ri.isValid())
                continue;

            const cgltf_mesh *mesh = findMeshForEntity(entity, _ncm, meshEntries);
            if (!mesh)
            {
                // Name-based matching failed — use sequential fallback.
                if (fallbackMeshIndex < meshEntries.size())
                {
                    mesh = meshEntries[fallbackMeshIndex].mesh;
                    TRACE("rebuildVertexBuffers: fallback mesh %zu for entity %zu", fallbackMeshIndex, ei);
                    fallbackMeshIndex++;
                }
                else
                {
                    TRACE("rebuildVertexBuffers: no mesh (named or fallback) for entity %zu", ei);
                    continue;
                }
            }

            for (cgltf_size pi = 0; pi < mesh->primitives_count; pi++)
            {
                const cgltf_primitive &prim = mesh->primitives[pi];

                if (prim.type != cgltf_primitive_type_triangles)
                {
                    TRACE("rebuildVertexBuffers: skipping non-triangle primitive");
                    continue;
                }

                // --- Find accessors for all attributes ---
                const cgltf_accessor *posAccessor = nullptr;
                const cgltf_accessor *nrmAccessor = nullptr;
                const cgltf_accessor *uvAccessor = nullptr;
                const cgltf_accessor *jointsAccessor = nullptr;
                const cgltf_accessor *weightsAccessor = nullptr;

                for (cgltf_size ai = 0; ai < prim.attributes_count; ai++)
                {
                    switch (prim.attributes[ai].type)
                    {
                    case cgltf_attribute_type_position:
                        posAccessor = prim.attributes[ai].data;
                        break;
                    case cgltf_attribute_type_normal:
                        nrmAccessor = prim.attributes[ai].data;
                        break;
                    case cgltf_attribute_type_texcoord:
                        if (!uvAccessor)
                            uvAccessor = prim.attributes[ai].data;
                        break;
                    case cgltf_attribute_type_joints:
                        if (!jointsAccessor)
                            jointsAccessor = prim.attributes[ai].data;
                        break;
                    case cgltf_attribute_type_weights:
                        if (!weightsAccessor)
                            weightsAccessor = prim.attributes[ai].data;
                        break;
                    default:
                        break;
                    }
                }
                if (!posAccessor)
                    continue;

                // --- Read indices ---
                std::vector<uint32_t> indices;
                if (prim.indices)
                {
                    indices.resize(prim.indices->count);
                    for (cgltf_size i = 0; i < prim.indices->count; i++)
                    {
                        indices[i] = (uint32_t)cgltf_accessor_read_index(prim.indices, i);
                    }
                }
                else
                {
                    cgltf_size vertexCount = posAccessor->count;
                    indices.resize(vertexCount);
                    for (cgltf_size i = 0; i < vertexCount; i++)
                    {
                        indices[i] = (uint32_t)i;
                    }
                }

                if (indices.size() < 3 || indices.size() % 3 != 0)
                    continue;

                uint32_t triangleCount = (uint32_t)(indices.size() / 3);
                uint32_t newVertexCount = triangleCount * 3;

                // --- Unpack source attributes ---
                size_t posComponents = cgltf_num_components(posAccessor->type);
                std::vector<float> srcPositions(posAccessor->count * posComponents);
                cgltf_accessor_unpack_floats(posAccessor, srcPositions.data(), srcPositions.size());

                std::vector<float> srcNormals;
                size_t nrmComponents = 0;
                if (nrmAccessor)
                {
                    nrmComponents = cgltf_num_components(nrmAccessor->type);
                    srcNormals.resize(nrmAccessor->count * nrmComponents);
                    cgltf_accessor_unpack_floats(nrmAccessor, srcNormals.data(), srcNormals.size());
                }

                std::vector<float> srcUVs;
                size_t uvComponents = 0;
                if (uvAccessor)
                {
                    uvComponents = cgltf_num_components(uvAccessor->type);
                    srcUVs.resize(uvAccessor->count * uvComponents);
                    cgltf_accessor_unpack_floats(uvAccessor, srcUVs.data(), srcUVs.size());
                }

                bool hasSkinning = jointsAccessor && weightsAccessor;
                std::vector<float> srcJoints;
                std::vector<float> srcWeights;
                if (hasSkinning)
                {
                    size_t jc = cgltf_num_components(jointsAccessor->type);
                    srcJoints.resize(jointsAccessor->count * jc);
                    cgltf_accessor_unpack_floats(jointsAccessor, srcJoints.data(), srcJoints.size());

                    size_t wc = cgltf_num_components(weightsAccessor->type);
                    srcWeights.resize(weightsAccessor->count * wc);
                    cgltf_accessor_unpack_floats(weightsAccessor, srcWeights.data(), srcWeights.size());
                }

                // --- Unweld: duplicate vertices per triangle ---
                std::vector<float> newPositions(newVertexCount * 3);
                std::vector<float> newNormals(newVertexCount * 3);
                std::vector<float> newUVs(newVertexCount * 2);
                std::vector<float> newBarycentrics(newVertexCount * 4);
                std::vector<uint8_t> newJoints;
                std::vector<float> newWeights;
                if (hasSkinning)
                {
                    newJoints.resize(newVertexCount * 4);
                    newWeights.resize(newVertexCount * 4);
                }

                const float bary[3][4] = {
                    {1.0f, 0.0f, 0.0f, 0.0f},
                    {0.0f, 1.0f, 0.0f, 0.0f},
                    {0.0f, 0.0f, 1.0f, 0.0f}};

                for (uint32_t t = 0; t < triangleCount; t++)
                {
                    for (int v = 0; v < 3; v++)
                    {
                        uint32_t srcIdx = indices[t * 3 + v];
                        uint32_t dstIdx = t * 3 + v;

                        // Position
                        newPositions[dstIdx * 3 + 0] = srcPositions[srcIdx * posComponents + 0];
                        newPositions[dstIdx * 3 + 1] = srcPositions[srcIdx * posComponents + 1];
                        newPositions[dstIdx * 3 + 2] = srcPositions[srcIdx * posComponents + 2];

                        // Normal
                        if (nrmAccessor && srcIdx < nrmAccessor->count)
                        {
                            newNormals[dstIdx * 3 + 0] = srcNormals[srcIdx * nrmComponents + 0];
                            newNormals[dstIdx * 3 + 1] = srcNormals[srcIdx * nrmComponents + 1];
                            newNormals[dstIdx * 3 + 2] = srcNormals[srcIdx * nrmComponents + 2];
                        }
                        else
                        {
                            newNormals[dstIdx * 3 + 0] = 0.0f;
                            newNormals[dstIdx * 3 + 1] = 1.0f;
                            newNormals[dstIdx * 3 + 2] = 0.0f;
                        }

                        // UV
                        if (uvAccessor && srcIdx < uvAccessor->count)
                        {
                            newUVs[dstIdx * 2 + 0] = srcUVs[srcIdx * uvComponents + 0];
                            newUVs[dstIdx * 2 + 1] = srcUVs[srcIdx * uvComponents + 1];
                        }
                        else
                        {
                            newUVs[dstIdx * 2 + 0] = 0.0f;
                            newUVs[dstIdx * 2 + 1] = 0.0f;
                        }

                        // Barycentric
                        newBarycentrics[dstIdx * 4 + 0] = bary[v][0];
                        newBarycentrics[dstIdx * 4 + 1] = bary[v][1];
                        newBarycentrics[dstIdx * 4 + 2] = bary[v][2];
                        newBarycentrics[dstIdx * 4 + 3] = bary[v][3];

                        // Bone indices/weights
                        if (hasSkinning)
                        {
                            size_t jc = cgltf_num_components(jointsAccessor->type);
                            size_t wc = cgltf_num_components(weightsAccessor->type);
                            for (int k = 0; k < 4; k++)
                            {
                                newJoints[dstIdx * 4 + k] = (k < (int)jc && srcIdx < jointsAccessor->count)
                                                                ? (uint8_t)srcJoints[srcIdx * jc + k]
                                                                : 0;
                                newWeights[dstIdx * 4 + k] = (k < (int)wc && srcIdx < weightsAccessor->count)
                                                                 ? srcWeights[srcIdx * wc + k]
                                                                 : 0.0f;
                            }
                        }
                    }
                }

                // --- Build tangent quaternions from normals ---
                std::vector<filament::math::ushort3> tris(triangleCount);
                for (uint32_t i = 0; i < newVertexCount; i += 3)
                {
                    tris[i / 3] = {(uint16_t)i, (uint16_t)(i + 1), (uint16_t)(i + 2)};
                }

                geometry::SurfaceOrientation::Builder orientBuilder;
                orientBuilder.vertexCount(newVertexCount)
                    .normals((filament::math::float3 *)newNormals.data())
                    .positions((filament::math::float3 *)newPositions.data())
                    .uvs((filament::math::float2 *)newUVs.data())
                    .triangleCount(tris.size())
                    .triangles(tris.data());

                auto orientation = orientBuilder.build();
                std::vector<filament::math::quatf> tangentQuats(newVertexCount);
                orientation->getQuats(tangentQuats.data(), newVertexCount);

                // --- Build VertexBuffer ---
                // Buffer layout: POSITION(0), TANGENTS(1), UV0(2), CUSTOM0(3), COLOR(4), [BONE_INDICES(5), BONE_WEIGHTS(6)]
                uint8_t bufferCount = hasSkinning ? 7 : 5;

                auto vbBuilder = VertexBuffer::Builder()
                                     .vertexCount(newVertexCount)
                                     .bufferCount(bufferCount)
                                     .enableBufferObjects()
                                     .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                                     .attribute(VertexAttribute::TANGENTS, 1, VertexBuffer::AttributeType::FLOAT4)
                                     .attribute(VertexAttribute::UV0, 2, VertexBuffer::AttributeType::FLOAT2)
                                     .attribute(VertexAttribute::CUSTOM0, 3, VertexBuffer::AttributeType::FLOAT4)
                                     .attribute(VertexAttribute::COLOR, 4, VertexBuffer::AttributeType::FLOAT4);

                if (hasSkinning)
                {
                    vbBuilder
                        .attribute(VertexAttribute::BONE_INDICES, 5, VertexBuffer::AttributeType::UBYTE4)
                        .attribute(VertexAttribute::BONE_WEIGHTS, 6, VertexBuffer::AttributeType::FLOAT4);
                }

                VertexBuffer *vb = vbBuilder.build(*_engine);

                // Buffer 0: POSITION
                size_t posDataSize = newVertexCount * 3 * sizeof(float);
                float *posData = (float *)malloc(posDataSize);
                memcpy(posData, newPositions.data(), posDataSize);
                BufferObject *posBO = BufferObject::Builder().size(posDataSize).build(*_engine);
                posBO->setBuffer(*_engine, BufferObject::BufferDescriptor(posData, posDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 0, posBO);

                // Buffer 1: TANGENTS
                size_t tangDataSize = newVertexCount * sizeof(filament::math::quatf);
                float *tangData = (float *)malloc(tangDataSize);
                memcpy(tangData, tangentQuats.data(), tangDataSize);
                BufferObject *tangBO = BufferObject::Builder().size(tangDataSize).build(*_engine);
                tangBO->setBuffer(*_engine, BufferObject::BufferDescriptor(tangData, tangDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 1, tangBO);

                // Buffer 2: UV0
                size_t uvDataSize = newVertexCount * 2 * sizeof(float);
                float *uvData = (float *)malloc(uvDataSize);
                memcpy(uvData, newUVs.data(), uvDataSize);
                BufferObject *uvBO = BufferObject::Builder().size(uvDataSize).build(*_engine);
                uvBO->setBuffer(*_engine, BufferObject::BufferDescriptor(uvData, uvDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 2, uvBO);

                // Buffer 3: CUSTOM0 (barycentrics)
                size_t baryDataSize = newVertexCount * 4 * sizeof(float);
                float *baryData = (float *)malloc(baryDataSize);
                memcpy(baryData, newBarycentrics.data(), baryDataSize);
                BufferObject *baryBO = BufferObject::Builder().size(baryDataSize).build(*_engine);
                baryBO->setBuffer(*_engine, BufferObject::BufferDescriptor(baryData, baryDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 3, baryBO);

                // Buffer 4: COLOR (dummy, all white = 1.0)
                size_t colorDataSize = newVertexCount * 4 * sizeof(float);
                float *colorData = (float *)malloc(colorDataSize);
                for (uint32_t i = 0; i < newVertexCount * 4; i++) {
                    colorData[i] = 1.0f;
                }
                BufferObject *colorBO = BufferObject::Builder().size(colorDataSize).build(*_engine);
                colorBO->setBuffer(*_engine, BufferObject::BufferDescriptor(colorData, colorDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 4, colorBO);

                _preservedBufferObjects.push_back(posBO);
                _preservedBufferObjects.push_back(tangBO);
                _preservedBufferObjects.push_back(uvBO);
                _preservedBufferObjects.push_back(baryBO);
                _preservedBufferObjects.push_back(colorBO);

                if (hasSkinning)
                {
                    // Buffer 5: BONE_INDICES
                    size_t jointDataSize = newVertexCount * 4 * sizeof(uint8_t);
                    uint8_t *jointData = (uint8_t *)malloc(jointDataSize);
                    memcpy(jointData, newJoints.data(), jointDataSize);
                    BufferObject *jointBO = BufferObject::Builder().size(jointDataSize).build(*_engine);
                    jointBO->setBuffer(*_engine, BufferObject::BufferDescriptor(jointData, jointDataSize, FREE_CB));
                    vb->setBufferObjectAt(*_engine, 5, jointBO);

                    // Buffer 6: BONE_WEIGHTS
                    size_t weightDataSize = newVertexCount * 4 * sizeof(float);
                    float *weightData = (float *)malloc(weightDataSize);
                    memcpy(weightData, newWeights.data(), weightDataSize);
                    BufferObject *weightBO = BufferObject::Builder().size(weightDataSize).build(*_engine);
                    weightBO->setBuffer(*_engine, BufferObject::BufferDescriptor(weightData, weightDataSize, FREE_CB));
                    vb->setBufferObjectAt(*_engine, 6, weightBO);

                    _preservedBufferObjects.push_back(jointBO);
                    _preservedBufferObjects.push_back(weightBO);
                }

                // --- Build sequential IndexBuffer ---
                size_t indexDataSize = newVertexCount * sizeof(uint32_t);
                uint32_t *newIndices = (uint32_t *)malloc(indexDataSize);
                for (uint32_t i = 0; i < newVertexCount; i++)
                {
                    newIndices[i] = i;
                }

                IndexBuffer *ib = IndexBuffer::Builder()
                                      .indexCount(newVertexCount)
                                      .bufferType(IndexBuffer::IndexType::UINT)
                                      .build(*_engine);
                ib->setBuffer(*_engine,
                              IndexBuffer::BufferDescriptor(newIndices, indexDataSize, FREE_CB));

                // --- Replace geometry on the renderable ---
                rm.setGeometryAt(ri, pi,
                                 RenderableManager::PrimitiveType::TRIANGLES,
                                 vb, ib, 0, newVertexCount);

                _preservedVertexBuffers.push_back(vb);
                _preservedIndexBuffers.push_back(ib);
                _preservedIndexCounts.push_back(newVertexCount);

                TRACE("rebuildVertexBuffers: primitive %zu unwelded %zu -> %u vertices (skinned=%d)",
                      pi, indices.size(), newVertexCount, hasSkinning);
            }
        }

        // Also update all pre-allocated instance entities with the rebuilt geometry.
        // Instance renderables reference the original buffers; we need to point them
        // at the new buffers that include barycentric coordinates (CUSTOM0).
        // We iterate instances in the same entity order as the root loop above,
        // matching bufferIndex to the preserved buffers created for each primitive.
        size_t totalBuffers = _preservedVertexBuffers.size();
        auto instanceCount = _asset->getAssetInstanceCount();
        for (size_t inst = 0; inst < instanceCount; inst++)
        {
            auto *filamentInstance = _asset->getAssetInstances()[inst];
            auto *instEntities = filamentInstance->getEntities();
            size_t instEntityCount = filamentInstance->getEntityCount();

            size_t bufferIndex = 0;
            for (size_t ei = 0; ei < instEntityCount && bufferIndex < totalBuffers; ei++)
            {
                auto instRi = rm.getInstance(instEntities[ei]);
                if (!instRi.isValid())
                    continue;

                size_t primCount = rm.getPrimitiveCount(instRi);
                for (size_t pi = 0; pi < primCount && bufferIndex < totalBuffers; pi++)
                {
                    rm.setGeometryAt(instRi, pi,
                                     RenderableManager::PrimitiveType::TRIANGLES,
                                     _preservedVertexBuffers[bufferIndex],
                                     _preservedIndexBuffers[bufferIndex],
                                     0, _preservedIndexCounts[bufferIndex]);
                    bufferIndex++;
                }
            }
        }

        _geometryPreserved = true;
    }

} // namespace thermion
