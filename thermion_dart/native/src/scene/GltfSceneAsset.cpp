
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
        bool rebuildVertices,
        MaterialInstance **materialInstances,
        size_t materialInstanceCount) : _asset(asset),
                                        _assetLoader(assetLoader),
                                        _engine(engine),
                                        _ncm(ncm),
                                        _materialInstances(materialInstances),
                                        _materialInstanceCount(materialInstanceCount)
    {
        if (rebuildVertices)
        {
            rebuildVertexBuffers();
        }
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

            for (size_t ei = 0; ei < instEntityCount; ei++)
            {
                auto instRi = rm.getInstance(instEntities[ei]);
                if (!instRi.isValid())
                    continue;

                std::string instEntityName;
                auto ni4 = _ncm->getInstance(instEntities[ei]);
                if (ni4.isValid())
                {
                    auto n4 = _ncm->getName(ni4);
                    if (n4)
                        instEntityName = n4;
                }

                // Match by name against the entityBufferMap built during rebuildVertexBuffers
                size_t primIdx = 0;
                for (const auto &entry : _entityBufferMap)
                {
                    if (entry.first == instEntityName)
                    {
                        size_t bufferIndex = entry.second;
                        rm.setGeometryAt(instRi, primIdx,
                                         RenderableManager::PrimitiveType::TRIANGLES,
                                         _preservedVertexBuffers[bufferIndex],
                                         _preservedIndexBuffers[bufferIndex],
                                         0, _preservedIndexCounts[bufferIndex]);
                        primIdx++;
                    }
                }
                TRACE("createInstance: entity '%s' applied %zu primitives", instEntityName.c_str(), primIdx);
            }
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

        // Log all mesh entries for debugging
        for (size_t mi = 0; mi < meshEntries.size(); mi++)
        {
            Log("  meshEntry[%zu]: nodeName='%s' meshName='%s'",
                mi,
                meshEntries[mi].name ? meshEntries[mi].name : "(null)",
                meshEntries[mi].meshName ? meshEntries[mi].meshName : "(null)");
        }

        // Fallback index for entities without names: assign mesh entries
        // sequentially to renderable entities that fail name matching.
        size_t fallbackMeshIndex = 0;

        for (size_t ei = 0; ei < renderableCount; ei++)
        {
            auto entity = renderableEntities[ei];
            auto ri = rm.getInstance(entity);
            if (!ri.isValid())
                continue;

            // Log entity name
            const char *entityName = "(no name)";
            auto ni = _ncm->getInstance(entity);
            if (ni.isValid())
            {
                auto n = _ncm->getName(ni);
                if (n && strlen(n) > 0)
                    entityName = n;
            }

            const cgltf_mesh *mesh = findMeshForEntity(entity, _ncm, meshEntries);
            if (!mesh)
            {
                // Name-based matching failed — use sequential fallback.
                if (fallbackMeshIndex < meshEntries.size())
                {
                    mesh = meshEntries[fallbackMeshIndex].mesh;
                    Log("rebuildVertexBuffers: entity[%zu] name='%s' -> FALLBACK mesh %zu", ei, entityName, fallbackMeshIndex);
                    fallbackMeshIndex++;
                }
                else
                {
                    Log("rebuildVertexBuffers: entity[%zu] name='%s' -> NO MESH", ei, entityName);
                    continue;
                }
            }
            else
            {
                Log("rebuildVertexBuffers: entity[%zu] name='%s' -> matched mesh '%s'",
                    ei, entityName, mesh->name ? mesh->name : "(null)");
            }

            size_t filamentPrimCount = rm.getPrimitiveCount(ri);
            Log("  cgltf primitives=%zu, filament primitives=%zu", mesh->primitives_count, filamentPrimCount);

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
                const cgltf_accessor *tanAccessor = nullptr;
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
                    case cgltf_attribute_type_tangent:
                        tanAccessor = prim.attributes[ai].data;
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
                cgltf_size posUnpacked = cgltf_accessor_unpack_floats(posAccessor, srcPositions.data(), srcPositions.size());

                Log("  prim[%zu]: posAccessor count=%zu components=%zu unpacked=%zu bufferView=%p",
                    pi, (size_t)posAccessor->count, posComponents, (size_t)posUnpacked,
                    (void*)posAccessor->buffer_view);
                if (posAccessor->buffer_view) {
                    Log("    bufferView: offset=%zu size=%zu buffer=%p",
                        posAccessor->buffer_view->offset,
                        posAccessor->buffer_view->size,
                        (void*)posAccessor->buffer_view->buffer);
                    if (posAccessor->buffer_view->buffer) {
                        Log("    buffer: size=%zu data=%p",
                            posAccessor->buffer_view->buffer->size,
                            posAccessor->buffer_view->buffer->data);
                    }
                }
                // Log first 3 positions as sample
                if (posUnpacked >= 9) {
                    Log("    pos[0]=(%f,%f,%f) pos[1]=(%f,%f,%f) pos[2]=(%f,%f,%f)",
                        srcPositions[0], srcPositions[1], srcPositions[2],
                        srcPositions[3], srcPositions[4], srcPositions[5],
                        srcPositions[6], srcPositions[7], srcPositions[8]);
                }
                Log("  prim[%zu]: indices=%zu triangles=%u newVertexCount=%u",
                    pi, indices.size(), triangleCount, newVertexCount);

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
                    cgltf_size uvUnpacked = cgltf_accessor_unpack_floats(uvAccessor, srcUVs.data(), srcUVs.size());
                    Log("    uvAccessor: count=%zu components=%zu unpacked=%zu",
                        (size_t)uvAccessor->count, uvComponents, (size_t)uvUnpacked);
                    if (uvUnpacked >= 4) {
                        Log("    uv[0]=(%f,%f) uv[1]=(%f,%f)",
                            srcUVs[0], srcUVs[1], srcUVs[2], srcUVs[3]);
                    }
                    if (uvUnpacked == 0) {
                        Log("    WARNING: cgltf_accessor_unpack_floats returned 0 for UVs!");
                    }
                }
                else
                {
                    Log("    WARNING: no UV accessor for this primitive");
                }

                std::vector<float> srcTangents;
                size_t tanComponents = 0;
                if (tanAccessor)
                {
                    tanComponents = cgltf_num_components(tanAccessor->type);
                    srcTangents.resize(tanAccessor->count * tanComponents);
                    cgltf_accessor_unpack_floats(tanAccessor, srcTangents.data(), srcTangents.size());
                    Log("    tangentAccessor: count=%zu components=%zu", (size_t)tanAccessor->count, tanComponents);
                }
                else
                {
                    Log("    no tangent accessor, will recompute from geometry");
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
                std::vector<float> newTangents; // float4 (xyz=tangent, w=sign)
                if (tanAccessor)
                {
                    newTangents.resize(newVertexCount * 4);
                }
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

                        // Tangent (float4: xyz=tangent, w=handedness)
                        if (tanAccessor && srcIdx < tanAccessor->count)
                        {
                            newTangents[dstIdx * 4 + 0] = srcTangents[srcIdx * tanComponents + 0];
                            newTangents[dstIdx * 4 + 1] = srcTangents[srcIdx * tanComponents + 1];
                            newTangents[dstIdx * 4 + 2] = srcTangents[srcIdx * tanComponents + 2];
                            newTangents[dstIdx * 4 + 3] = (tanComponents >= 4)
                                                              ? srcTangents[srcIdx * tanComponents + 3]
                                                              : 1.0f;
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

                // --- Build tangent quaternions ---
                geometry::SurfaceOrientation::Builder orientBuilder;
                orientBuilder.vertexCount(newVertexCount)
                    .normals((filament::math::float3 *)newNormals.data())
                    .positions((filament::math::float3 *)newPositions.data());

                if (tanAccessor)
                {
                    // Use original tangent vectors from glTF for correct normal mapping
                    orientBuilder.tangents((filament::math::float4 *)newTangents.data());
                }
                else
                {
                    // No tangent data — recompute from geometry
                    std::vector<filament::math::uint3> tris(triangleCount);
                    for (uint32_t i = 0; i < newVertexCount; i += 3)
                    {
                        tris[i / 3] = {i, i + 1, i + 2};
                    }
                    orientBuilder.uvs((filament::math::float2 *)newUVs.data())
                        .triangleCount(tris.size())
                        .triangles(tris.data());
                }

                auto orientation = orientBuilder.build();
                std::vector<filament::math::short4> tangentQuats(newVertexCount);
                orientation->getQuats(tangentQuats.data(), newVertexCount);

                // --- Build VertexBuffer ---
                // Buffer layout: POSITION(0), TANGENTS(1), UV0(2), CUSTOM0(3), COLOR(4), [BONE_INDICES(5), BONE_WEIGHTS(6)]
                uint8_t bufferCount = hasSkinning ? 7 : 5;

                auto vbBuilder = VertexBuffer::Builder()
                                     .vertexCount(newVertexCount)
                                     .bufferCount(bufferCount)
                                     .enableBufferObjects()
                                     .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                                     .attribute(VertexAttribute::TANGENTS, 1, VertexBuffer::AttributeType::SHORT4)
                                     .normalized(VertexAttribute::TANGENTS)
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

                // Buffer 1: TANGENTS (SHORT4 quantized quaternions, matching gltfio's format)
                size_t tangDataSize = newVertexCount * sizeof(filament::math::short4);
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
        // Skip instance 0 — the primary loop above already set its geometry
        // correctly via name-matched entity→mesh mapping.
        // For instances 1+, we need to apply the preserved buffers. We match
        // by entity name to avoid order-dependent bugs.
        size_t totalBuffers = _preservedVertexBuffers.size();
        auto instanceCount = _asset->getAssetInstanceCount();

        // Build a map from entity name → list of (bufferIndex) for correct matching.
        // The primary loop built preserved buffers in getRenderableEntities() order;
        // record which entity name each buffer belongs to.
        {
            size_t bufIdx = 0;
            for (size_t ei = 0; ei < renderableCount && bufIdx < totalBuffers; ei++)
            {
                auto ent = renderableEntities[ei];
                auto entRi = rm.getInstance(ent);
                if (!entRi.isValid())
                    continue;
                std::string eName;
                auto ni2 = _ncm->getInstance(ent);
                if (ni2.isValid())
                {
                    auto n2 = _ncm->getName(ni2);
                    if (n2)
                        eName = n2;
                }
                size_t primCount = rm.getPrimitiveCount(entRi);
                for (size_t pi = 0; pi < primCount && bufIdx < totalBuffers; pi++)
                {
                    _entityBufferMap.push_back({eName, bufIdx});
                    bufIdx++;
                }
            }
        }

        // Skip instance 0 — the primary loop above already set its geometry
        // correctly via name-matched entity→mesh mapping.
        for (size_t inst = 1; inst < instanceCount; inst++)
        {
            auto *filamentInstance = _asset->getAssetInstances()[inst];
            auto *instEntities = filamentInstance->getEntities();
            size_t instEntityCount = filamentInstance->getEntityCount();

            for (size_t ei = 0; ei < instEntityCount; ei++)
            {
                auto instRi = rm.getInstance(instEntities[ei]);
                if (!instRi.isValid())
                    continue;

                std::string instEntityName;
                auto ni3 = _ncm->getInstance(instEntities[ei]);
                if (ni3.isValid())
                {
                    auto n3 = _ncm->getName(ni3);
                    if (n3)
                        instEntityName = n3;
                }

                // Find the matching buffer(s) by name
                size_t primIdx = 0;
                for (const auto &entry : _entityBufferMap)
                {
                    if (entry.first == instEntityName)
                    {
                        size_t bufferIndex = entry.second;
                        rm.setGeometryAt(instRi, primIdx,
                                         RenderableManager::PrimitiveType::TRIANGLES,
                                         _preservedVertexBuffers[bufferIndex],
                                         _preservedIndexBuffers[bufferIndex],
                                         0, _preservedIndexCounts[bufferIndex]);
                        primIdx++;
                    }
                }
                TRACE("rebuildVertexBuffers: inst[%zu] entity '%s' applied %zu primitives",
                      inst, instEntityName.c_str(), primIdx);
            }
        }

        _geometryPreserved = true;
    }

} // namespace thermion
