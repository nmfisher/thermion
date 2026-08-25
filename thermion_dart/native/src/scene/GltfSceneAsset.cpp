
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

#include <geometry/SurfaceOrientation.h>

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
        for (auto *bo : _smoothTangentBOs)
        {
            _engine->destroy(bo);
        }
        for (auto *bo : _flatTangentBOs)
        {
            _engine->destroy(bo);
        }
        for (auto *mtb : _ownedMorphTargetBuffers)
        {
            _engine->destroy(mtb);
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
            size_t appliedCount = 0;
            for (size_t ei = 0; ei < instEntityCount && bufferIndex < totalBuffers; ei++)
            {
                auto instRi = rm.getInstance(instEntities[ei]);
                if (!instRi.isValid())
                    continue;
                size_t primCount = rm.getPrimitiveCount(instRi);

                // Morph-bearing entities need a full renderable rebuild rather
                // than setGeometryAt (see rebuildVertexBuffers).
                if (rebuildRenderableWithMorphs(instEntities[ei], bufferIndex))
                {
                    bufferIndex += primCount;
                    appliedCount += primCount;
                    // The rebuild resets the bones UBO to identity; refresh
                    // this instance's skinning before it is next rendered.
                    instance->getAnimator()->updateBoneMatrices();
                    continue;
                }

                for (size_t pi = 0; pi < primCount && bufferIndex < totalBuffers; pi++)
                {
                    // Placeholder slots (non-triangle prims, or entities
                    // that had no mesh match): leave the gltfio-built
                    // geometry on this primitive untouched.
                    if (!_preservedVertexBuffers[bufferIndex])
                    {
                        bufferIndex++;
                        continue;
                    }
                    rm.setGeometryAt(instRi, pi,
                                     RenderableManager::PrimitiveType::TRIANGLES,
                                     _preservedVertexBuffers[bufferIndex],
                                     _preservedIndexBuffers[bufferIndex],
                                     0, _preservedIndexCounts[bufferIndex]);
                    bufferIndex++;
                    appliedCount++;
                }
            }
            TRACE("createInstance: applied %zu preserved geometry buffers to new instance", appliedCount);
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
    { delete[] static_cast<uint8_t *>(mem); };

    // Build a map from node/mesh name to cgltf_mesh for all nodes in the asset.
    // Multiple nodes can reference the same mesh, so we also build a flat list
    // of (name, mesh) pairs to handle unnamed nodes by index.
    struct MeshEntry
    {
        const char *name;     // node name (may be null)
        const char *meshName; // mesh name (may be null)
        const cgltf_node *node;
        const cgltf_mesh *mesh;
    };

    static void collectAllMeshEntries(const cgltf_data *data, std::vector<MeshEntry> &entries)
    {
        for (cgltf_size i = 0; i < data->nodes_count; i++)
        {
            const cgltf_node &node = data->nodes[i];
            if (node.mesh)
            {
                entries.push_back({node.name, node.mesh->name, &node, node.mesh});
            }
        }
    }

    // Find the cgltf_node for a given renderable entity by matching names.
    static const cgltf_node *findNodeForEntity(
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
                return entry.node;
            }
            if (entry.meshName && strcmp(entry.meshName, entityName) == 0)
            {
                return entry.node;
            }
        }
        return nullptr;
    }

    // Computes the tangent-frame quaternions for a single morph target,
    // replicating gltfio's TangentsJob (libs/gltfio/src/TangentsJob.cpp at
    // Filament v1.75.0): the SurfaceOrientation builder is fed the WELDED base
    // attributes with the target's deltas added, which is exactly what gltfio
    // uploads into its own MorphTargetBuffer. Computing on the welded data
    // (instead of the unwelded copies) means the resulting quaternions are
    // bit-identical to the pre-rebuild ones; the caller then duplicates them
    // into unwelded render vertices with the same index remap used for the
    // base attributes.
    //
    // Missing delta accessors are treated as zero deltas (gltfio's TangentsJob
    // simply skips the addition in that case).
    static void computeMorphTangentQuats(
        const cgltf_accessor *posAccessor, const std::vector<float> &srcPositions,
        const cgltf_accessor *nrmAccessor, const std::vector<float> &srcNormals, size_t nrmComponents,
        const cgltf_accessor *tanAccessor, const std::vector<float> &srcTangents, size_t tanComponents,
        const cgltf_accessor *uvAccessor, const std::vector<float> &srcUVs, size_t uvComponents,
        const cgltf_accessor *posDeltaAccessor,
        const cgltf_accessor *nrmDeltaAccessor,
        const cgltf_accessor *tanDeltaAccessor,
        const std::vector<uint32_t> &indices,
        std::vector<filament::math::short4> &outQuats)
    {
        using namespace filament::math;
        const cgltf_size vertexCount = posAccessor->count;
        if (vertexCount == 0)
        {
            return;
        }

        // Add a vec3 delta accessor to a float array, element-wise.
        auto addDeltas = [&vertexCount](std::vector<float> &values, size_t components,
                                        const cgltf_accessor *deltaAccessor)
        {
            if (!deltaAccessor)
            {
                return;
            }
            const size_t deltaComponents = cgltf_num_components(deltaAccessor->type);
            std::vector<float> deltas(deltaAccessor->count * deltaComponents);
            cgltf_accessor_unpack_floats(deltaAccessor, deltas.data(), deltas.size());
            const size_t count = std::min((size_t)vertexCount, (size_t)deltaAccessor->count);
            for (size_t i = 0; i < count; i++)
            {
                for (size_t c = 0; c < 3 && c < components && c < deltaComponents; c++)
                {
                    values[i * components + c] += deltas[i * deltaComponents + c];
                }
            }
        };

        // Positions (always present for triangle primitives reaching here).
        std::vector<float> morphedPositions(srcPositions);

        geometry::SurfaceOrientation::Builder sob;
        sob.vertexCount(vertexCount);

        // Normals + normal deltas (only when the base mesh has normals).
        if (nrmAccessor && nrmAccessor->type == cgltf_type_vec3)
        {
            std::vector<float> morphedNormals(srcNormals);
            addDeltas(morphedNormals, nrmComponents, nrmDeltaAccessor);
            sob.normals((float3 *)morphedNormals.data());
        }

        // Tangents (float4: xyz = tangent, w = handedness) + tangent deltas.
        if (tanAccessor && tanComponents >= 3)
        {
            std::vector<float> morphedTangents(vertexCount * 4);
            for (cgltf_size i = 0; i < vertexCount; i++)
            {
                morphedTangents[i * 4 + 0] = srcTangents[i * tanComponents + 0];
                morphedTangents[i * 4 + 1] = srcTangents[i * tanComponents + 1];
                morphedTangents[i * 4 + 2] = srcTangents[i * tanComponents + 2];
                morphedTangents[i * 4 + 3] = (tanComponents >= 4)
                                                 ? srcTangents[i * tanComponents + 3]
                                                 : 1.0f;
            }
            addDeltas(morphedTangents, 4, tanDeltaAccessor);
            sob.tangents((float4 *)morphedTangents.data());
        }

        // Positions + position deltas.
        if (posAccessor->type == cgltf_type_vec3)
        {
            addDeltas(morphedPositions, 3, posDeltaAccessor);
        }
        sob.positions((float3 *)morphedPositions.data());

        // Triangles from the (welded) index buffer, as in TangentsJob.
        const size_t triangleCount = indices.size() / 3;
        std::vector<filament::math::uint3> tris(triangleCount);
        for (size_t t = 0; t < triangleCount; t++)
        {
            tris[t] = {indices[t * 3 + 0], indices[t * 3 + 1], indices[t * 3 + 2]};
        }
        sob.triangleCount(triangleCount);
        sob.triangles(tris.data());

        // UVs (TangentsJob only supplies them when the accessor is a matching vec2).
        if (uvAccessor && uvAccessor->count == vertexCount &&
            uvAccessor->type == cgltf_type_vec2 && uvComponents >= 2)
        {
            sob.uvs((const float2 *)srcUVs.data());
        }

        outQuats.resize(vertexCount);
        auto *helper = sob.build();
        helper->getQuats(outQuats.data(), vertexCount);
        delete helper;
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

        // Use the root asset's getEntities() to match what getChildEntities() returns.
        // This ensures the entity enumeration order is consistent between rebuild
        // and queries.
        auto *allEntities = _asset->getEntities();
        size_t allEntityCount = _asset->getEntityCount();
        auto &rm = _engine->getRenderableManager();

        TRACE("rebuildVertexBuffers: meshEntries=%zu entityCount=%zu nodes=%zu",
              meshEntries.size(), allEntityCount, sourceData->nodes_count);

        // Fallback index for entities without names: assign mesh entries
        // sequentially to renderable entities that fail name matching.
        size_t fallbackMeshIndex = 0;

        for (size_t ei = 0; ei < allEntityCount; ei++)
        {
            auto entity = allEntities[ei];
            auto ri = rm.getInstance(entity);
            if (!ri.isValid())
                continue;

            // Store the mapping from entity to its starting primitive offset
            // BEFORE processing this entity's primitives
            _entityToPrimitiveOffset[utils::Entity::smuggle(entity)] = _preservedVertexBuffers.size();

            const cgltf_node *node = findNodeForEntity(entity, _ncm, meshEntries);
            const cgltf_mesh *mesh = nullptr;
            if (!node)
            {
                // Name-based matching failed — use sequential fallback.
                if (fallbackMeshIndex < meshEntries.size())
                {
                    node = meshEntries[fallbackMeshIndex].node;
                    TRACE("rebuildVertexBuffers: fallback mesh %zu for entity %zu", fallbackMeshIndex, ei);
                    fallbackMeshIndex++;
                }
                else
                {
                    // Pad placeholder slots so _preservedVertexBuffers stays
                    // 1:1 with the renderable's primitives. Downstream code
                    // (Dart's getFlatPrimitiveIndex, the per-instance update
                    // loops below) treats each slot as "the i-th renderable
                    // primitive of this asset" — skipping silently here would
                    // shift every subsequent entity's flat index.
                    size_t skippedPrimCount = rm.getPrimitiveCount(ri);
                    TRACE("rebuildVertexBuffers: no mesh (named or fallback) for entity %zu — padding %zu placeholder slots", ei, skippedPrimCount);
                    for (size_t pi = 0; pi < skippedPrimCount; pi++)
                    {
                        _preservedVertexBuffers.push_back(nullptr);
                        _preservedIndexBuffers.push_back(nullptr);
                        _preservedIndexCounts.push_back(0);
                        _smoothTangentBOs.push_back(nullptr);
                        _flatTangentBOs.push_back(nullptr);
                        _preservedMorphInfos.push_back({});
                    }
                    continue;
                }
            }
            mesh = node->mesh;

            // Morph-target bookkeeping for this entity. glTF requires all
            // primitives of a mesh to declare the same number of targets.
            const cgltf_size numMorphTargets =
                (mesh->primitives_count > 0) ? mesh->primitives[0].targets_count : 0;
            const size_t entitySlotStart = _preservedVertexBuffers.size();
            size_t morphingVertexCount = 0;
            struct PrimMorphUpload
            {
                std::vector<float> positionDeltas;          // unwelded, comps per vertex
                size_t positionComponents = 3;              // 3 (vec3) or 4 (vec4)
                std::vector<filament::math::short4> tangentQuats; // unwelded, empty when not computed
            };
            std::vector<std::vector<PrimMorphUpload>> morphUploads;
            std::vector<size_t> primMorphOffsets;

            for (cgltf_size pi = 0; pi < mesh->primitives_count; pi++)
            {
                const cgltf_primitive &prim = mesh->primitives[pi];

                if (prim.type != cgltf_primitive_type_triangles)
                {
                    // Push a placeholder so _preservedVertexBuffers stays
                    // 1:1 with the renderable's primitives. The unweld +
                    // barycentric pipeline only makes sense for triangles,
                    // so we leave the gltfio-built geometry untouched on
                    // this primitive. Callers (e.g. setStencilHighlight)
                    // null-check getPreservedVertexBuffer.
                    TRACE("rebuildVertexBuffers: placeholder for non-triangle primitive at entity %zu prim %zu", ei, pi);
                    _preservedVertexBuffers.push_back(nullptr);
                    _preservedIndexBuffers.push_back(nullptr);
                    _preservedIndexCounts.push_back(0);
                    _smoothTangentBOs.push_back(nullptr);
                    _flatTangentBOs.push_back(nullptr);
                    _preservedMorphInfos.push_back({});
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

                std::vector<float> srcTangents;
                size_t tanComponents = 0;
                if (tanAccessor)
                {
                    tanComponents = cgltf_num_components(tanAccessor->type);
                    srcTangents.resize(tanAccessor->count * tanComponents);
                    cgltf_accessor_unpack_floats(tanAccessor, srcTangents.data(), srcTangents.size());
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

                // --- Build smooth tangent quaternions ---
                // tris must outlive orientBuilder.build() since the builder stores a pointer
                std::vector<filament::math::uint3> tris;

                geometry::SurfaceOrientation::Builder smoothOrientBuilder;
                smoothOrientBuilder.vertexCount(newVertexCount)
                    .normals((filament::math::float3 *)newNormals.data())
                    .positions((filament::math::float3 *)newPositions.data());

                if (tanAccessor)
                {
                    smoothOrientBuilder.tangents((filament::math::float4 *)newTangents.data());
                }
                else
                {
                    tris.resize(triangleCount);
                    for (uint32_t i = 0; i < newVertexCount; i += 3)
                    {
                        tris[i / 3] = {i, i + 1, i + 2};
                    }
                    smoothOrientBuilder.uvs((filament::math::float2 *)newUVs.data())
                        .triangleCount(tris.size())
                        .triangles(tris.data());
                }

                auto *smoothOrientation = smoothOrientBuilder.build();
                std::vector<filament::math::short4> smoothTangentQuats(newVertexCount);
                smoothOrientation->getQuats(smoothTangentQuats.data(), newVertexCount);
                delete smoothOrientation;

                // --- Build flat tangent quaternions (face normals) ---
                std::vector<float> flatNormals(newVertexCount * 3);
                for (uint32_t t = 0; t < triangleCount; t++)
                {
                    uint32_t i0 = t * 3 + 0, i1 = t * 3 + 1, i2 = t * 3 + 2;
                    filament::math::float3 p0 = {newPositions[i0 * 3], newPositions[i0 * 3 + 1], newPositions[i0 * 3 + 2]};
                    filament::math::float3 p1 = {newPositions[i1 * 3], newPositions[i1 * 3 + 1], newPositions[i1 * 3 + 2]};
                    filament::math::float3 p2 = {newPositions[i2 * 3], newPositions[i2 * 3 + 1], newPositions[i2 * 3 + 2]};
                    filament::math::float3 fn = normalize(cross(p1 - p0, p2 - p0));
                    for (int v = 0; v < 3; v++)
                    {
                        uint32_t di = t * 3 + v;
                        flatNormals[di * 3 + 0] = fn.x;
                        flatNormals[di * 3 + 1] = fn.y;
                        flatNormals[di * 3 + 2] = fn.z;
                    }
                }

                // For flat normals, no tangent data from glTF is meaningful, so always recompute from geometry
                std::vector<filament::math::uint3> flatTris(triangleCount);
                for (uint32_t i = 0; i < newVertexCount; i += 3)
                {
                    flatTris[i / 3] = {i, i + 1, i + 2};
                }

                geometry::SurfaceOrientation::Builder flatOrientBuilder;
                flatOrientBuilder.vertexCount(newVertexCount)
                    .normals((filament::math::float3 *)flatNormals.data())
                    .positions((filament::math::float3 *)newPositions.data())
                    .uvs((filament::math::float2 *)newUVs.data())
                    .triangleCount(flatTris.size())
                    .triangles(flatTris.data());

                auto *flatOrientation = flatOrientBuilder.build();
                std::vector<filament::math::short4> flatTangentQuats(newVertexCount);
                flatOrientation->getQuats(flatTangentQuats.data(), newVertexCount);
                delete flatOrientation;

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
                auto *posData = new uint8_t[posDataSize];
                memcpy(posData, newPositions.data(), posDataSize);
                BufferObject *posBO = BufferObject::Builder().size(posDataSize).build(*_engine);
                posBO->setBuffer(*_engine, BufferObject::BufferDescriptor(posData, posDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 0, posBO);

                // Buffer 1: TANGENTS (SHORT4 quantized quaternions, matching gltfio's format)
                // Create both smooth and flat tangent BOs for runtime toggling.
                size_t tangDataSize = newVertexCount * sizeof(filament::math::short4);

                auto *smoothTangData = new uint8_t[tangDataSize];
                memcpy(smoothTangData, smoothTangentQuats.data(), tangDataSize);
                BufferObject *smoothTangBO = BufferObject::Builder().size(tangDataSize).build(*_engine);
                smoothTangBO->setBuffer(*_engine, BufferObject::BufferDescriptor(smoothTangData, tangDataSize, FREE_CB));

                auto *flatTangData = new uint8_t[tangDataSize];
                memcpy(flatTangData, flatTangentQuats.data(), tangDataSize);
                BufferObject *flatTangBO = BufferObject::Builder().size(tangDataSize).build(*_engine);
                flatTangBO->setBuffer(*_engine, BufferObject::BufferDescriptor(flatTangData, tangDataSize, FREE_CB));

                // Bind smooth by default
                vb->setBufferObjectAt(*_engine, 1, smoothTangBO);
                _smoothTangentBOs.push_back(smoothTangBO);
                _flatTangentBOs.push_back(flatTangBO);

                // Buffer 2: UV0
                size_t uvDataSize = newVertexCount * 2 * sizeof(float);
                auto *uvData = new uint8_t[uvDataSize];
                memcpy(uvData, newUVs.data(), uvDataSize);
                BufferObject *uvBO = BufferObject::Builder().size(uvDataSize).build(*_engine);
                uvBO->setBuffer(*_engine, BufferObject::BufferDescriptor(uvData, uvDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 2, uvBO);

                // Buffer 3: CUSTOM0 (barycentrics)
                size_t baryDataSize = newVertexCount * 4 * sizeof(float);
                auto *baryData = new uint8_t[baryDataSize];
                memcpy(baryData, newBarycentrics.data(), baryDataSize);
                BufferObject *baryBO = BufferObject::Builder().size(baryDataSize).build(*_engine);
                baryBO->setBuffer(*_engine, BufferObject::BufferDescriptor(baryData, baryDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 3, baryBO);

                // Buffer 4: COLOR (dummy, all white = 1.0)
                size_t colorDataSize = newVertexCount * 4 * sizeof(float);
                auto *colorData = new uint8_t[colorDataSize];
                auto *colorFloats = reinterpret_cast<float *>(colorData);
                for (uint32_t i = 0; i < newVertexCount * 4; i++) {
                    colorFloats[i] = 1.0f;
                }
                BufferObject *colorBO = BufferObject::Builder().size(colorDataSize).build(*_engine);
                colorBO->setBuffer(*_engine, BufferObject::BufferDescriptor(colorData, colorDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 4, colorBO);

                _preservedBufferObjects.push_back(posBO);
                _preservedBufferObjects.push_back(uvBO);
                _preservedBufferObjects.push_back(baryBO);
                _preservedBufferObjects.push_back(colorBO);

                if (hasSkinning)
                {
                    // Buffer 5: BONE_INDICES
                    size_t jointDataSize = newVertexCount * 4 * sizeof(uint8_t);
                    auto *jointData = new uint8_t[jointDataSize];
                    memcpy(jointData, newJoints.data(), jointDataSize);
                    BufferObject *jointBO = BufferObject::Builder().size(jointDataSize).build(*_engine);
                    jointBO->setBuffer(*_engine, BufferObject::BufferDescriptor(jointData, jointDataSize, FREE_CB));
                    vb->setBufferObjectAt(*_engine, 5, jointBO);

                    // Buffer 6: BONE_WEIGHTS
                    size_t weightDataSize = newVertexCount * 4 * sizeof(float);
                    auto *weightData = new uint8_t[weightDataSize];
                    memcpy(weightData, newWeights.data(), weightDataSize);
                    BufferObject *weightBO = BufferObject::Builder().size(weightDataSize).build(*_engine);
                    weightBO->setBuffer(*_engine, BufferObject::BufferDescriptor(weightData, weightDataSize, FREE_CB));
                    vb->setBufferObjectAt(*_engine, 6, weightBO);

                    _preservedBufferObjects.push_back(jointBO);
                    _preservedBufferObjects.push_back(weightBO);
                }

                // --- Build sequential IndexBuffer ---
                size_t indexDataSize = newVertexCount * sizeof(uint32_t);
                auto *newIndices = new uint8_t[indexDataSize];
                auto *indexPtr = reinterpret_cast<uint32_t *>(newIndices);
                for (uint32_t i = 0; i < newVertexCount; i++)
                {
                    indexPtr[i] = i;
                }

                IndexBuffer *ib = IndexBuffer::Builder()
                                      .indexCount(newVertexCount)
                                      .bufferType(IndexBuffer::IndexType::UINT)
                                      .build(*_engine);
                ib->setBuffer(*_engine,
                              IndexBuffer::BufferDescriptor(newIndices, indexDataSize, FREE_CB));

                // --- Unweld morph target deltas ---
                // The unwelded renderable no longer matches the gltfio-created
                // MorphTargetBuffer (which is sized for the welded vertex
                // count). Collect per-target unwelded deltas here; the entity
                // level code below uploads them into a replacement
                // MorphTargetBuffer and rebuilds the renderable against it.
                if (numMorphTargets > 0)
                {
                    primMorphOffsets.push_back(morphingVertexCount);
                    morphingVertexCount += newVertexCount;

                    std::vector<PrimMorphUpload> targetUploads;
                    for (cgltf_size ti = 0; ti < numMorphTargets; ti++)
                    {
                        const cgltf_morph_target &target = prim.targets[ti];
                        const cgltf_accessor *posDeltaAccessor = nullptr;
                        const cgltf_accessor *nrmDeltaAccessor = nullptr;
                        const cgltf_accessor *tanDeltaAccessor = nullptr;
                        for (cgltf_size ai = 0; ai < target.attributes_count; ai++)
                        {
                            switch (target.attributes[ai].type)
                            {
                            case cgltf_attribute_type_position:
                                posDeltaAccessor = target.attributes[ai].data;
                                break;
                            case cgltf_attribute_type_normal:
                                nrmDeltaAccessor = target.attributes[ai].data;
                                break;
                            case cgltf_attribute_type_tangent:
                                tanDeltaAccessor = target.attributes[ai].data;
                                break;
                            default:
                                break;
                            }
                        }

                        PrimMorphUpload upload;

                        // POSITION deltas: duplicate each source delta into the
                        // unwelded render vertex that references it. Missing
                        // delta accessors are zero deltas per the glTF spec.
                        upload.positionComponents = posDeltaAccessor
                                                        ? cgltf_num_components(posDeltaAccessor->type)
                                                        : 3;
                        upload.positionDeltas.assign(newVertexCount * upload.positionComponents, 0.0f);
                        if (posDeltaAccessor)
                        {
                            std::vector<float> srcDeltas(posDeltaAccessor->count *
                                                         upload.positionComponents);
                            cgltf_accessor_unpack_floats(posDeltaAccessor, srcDeltas.data(),
                                                         srcDeltas.size());
                            for (uint32_t r = 0; r < newVertexCount; r++)
                            {
                                const uint32_t srcIdx = indices[r];
                                if (srcIdx >= posDeltaAccessor->count)
                                {
                                    continue;
                                }
                                for (size_t c = 0; c < upload.positionComponents; c++)
                                {
                                    upload.positionDeltas[r * upload.positionComponents + c] =
                                        srcDeltas[srcIdx * upload.positionComponents + c];
                                }
                            }
                        }

                        // Tangent frames: replicate gltfio's gate (tangent jobs
                        // are only created for meshes with default weights,
                        // and per-target only when the target carries a
                        // TANGENT delta or the material is lit), then compute
                        // on the welded data exactly like TangentsJob before
                        // duplicating into unwelded vertices.
                        const bool hasTangentDelta = tanDeltaAccessor != nullptr;
                        const bool litMaterial = prim.material && !prim.material->unlit;
                        if (mesh->weights_count != 0 && (hasTangentDelta || litMaterial))
                        {
                            std::vector<filament::math::short4> srcQuats;
                            computeMorphTangentQuats(
                                posAccessor, srcPositions,
                                nrmAccessor, srcNormals, nrmComponents,
                                tanAccessor, srcTangents, tanComponents,
                                uvAccessor, srcUVs, uvComponents,
                                posDeltaAccessor, nrmDeltaAccessor, tanDeltaAccessor,
                                indices, srcQuats);
                            if (!srcQuats.empty())
                            {
                                upload.tangentQuats.resize(newVertexCount);
                                for (uint32_t r = 0; r < newVertexCount; r++)
                                {
                                    const uint32_t srcIdx = indices[r];
                                    upload.tangentQuats[r] =
                                        (srcIdx < srcQuats.size()) ? srcQuats[srcIdx]
                                                                   : filament::math::short4{0, 0, 0, 32767};
                                }
                            }
                        }

                        targetUploads.push_back(std::move(upload));
                    }
                    morphUploads.push_back(std::move(targetUploads));
                }

                // --- Replace geometry on the renderable ---
                rm.setGeometryAt(ri, pi,
                                 RenderableManager::PrimitiveType::TRIANGLES,
                                 vb, ib, 0, newVertexCount);

                _preservedVertexBuffers.push_back(vb);
                _preservedIndexBuffers.push_back(ib);
                _preservedIndexCounts.push_back(newVertexCount);
                _preservedMorphInfos.push_back({});

                TRACE("rebuildVertexBuffers: primitive %zu unwelded %zu -> %u vertices (skinned=%d)",
                      pi, indices.size(), newVertexCount, hasSkinning);
            }

            // --- Morph target replacement for this entity ---
            if (numMorphTargets > 0)
            {
                // A renderable rebuild requires rebuilt geometry on every
                // primitive (including placeholders for skipped ones), since
                // Builder::build re-specifies the whole component. Fall back
                // to the gltfio-built renderable (stale morph buffer) when
                // any primitive was not rebuilt.
                const size_t primsPushed = _preservedVertexBuffers.size() - entitySlotStart;
                bool fullyRebuilt = primsPushed == (size_t)mesh->primitives_count;
                for (size_t s = entitySlotStart;
                     fullyRebuilt && s < _preservedVertexBuffers.size(); s++)
                {
                    fullyRebuilt = _preservedVertexBuffers[s] != nullptr;
                }

                if (fullyRebuilt)
                {
                    MorphTargetBuffer *mtb = MorphTargetBuffer::Builder()
                                                 .count(numMorphTargets)
                                                 .vertexCount(morphingVertexCount)
                                                 .build(*_engine);
                    _ownedMorphTargetBuffers.push_back(mtb);

                    for (size_t pi = 0; pi < (size_t)mesh->primitives_count; pi++)
                    {
                        const size_t slot = entitySlotStart + pi;
                        const size_t primVertexCount = _preservedIndexCounts[slot];
                        _preservedMorphInfos[slot] = {mtb, primMorphOffsets[pi],
                                                      (size_t)numMorphTargets, node};
                        for (cgltf_size ti = 0; ti < numMorphTargets; ti++)
                        {
                            const PrimMorphUpload &upload = morphUploads[pi][ti];
                            if (upload.positionComponents == 3)
                            {
                                mtb->setPositionsAt(*_engine, ti,
                                                    (const filament::math::float3 *)upload.positionDeltas.data(),
                                                    primVertexCount, primMorphOffsets[pi]);
                            }
                            else
                            {
                                mtb->setPositionsAt(*_engine, ti,
                                                    (const filament::math::float4 *)upload.positionDeltas.data(),
                                                    primVertexCount, primMorphOffsets[pi]);
                            }
                            if (!upload.tangentQuats.empty())
                            {
                                mtb->setTangentsAt(*_engine, ti,
                                                   upload.tangentQuats.data(),
                                                   primVertexCount, primMorphOffsets[pi]);
                            }
                        }
                    }

                    // Replaces the renderable component (geometry, morphing,
                    // materials, shadows, skinning, glTF default weights).
                    rebuildRenderableWithMorphs(entity, entitySlotStart);
                }
                else
                {
                    TRACE("rebuildVertexBuffers: entity %zu has morph targets but not all primitives "
                          "were rebuilt — leaving gltfio renderable/morph buffer in place",
                          ei);
                }
            }
        }

        // Update pre-allocated instances 1+ with the rebuilt geometry.
        // Instance 0 was already handled by the primary loop above.
        // Sequential indexing is safe here because both the primary loop and
        // this loop enumerate entities via getEntities() in the same order.
        size_t totalBuffers = _preservedVertexBuffers.size();
        auto instanceCount = _asset->getAssetInstanceCount();
        for (size_t inst = 1; inst < instanceCount; inst++)
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

                // Entities with a replacement morph buffer need a full
                // renderable rebuild (Filament only attaches a
                // MorphTargetBuffer at build time); this also re-applies the
                // rebuilt geometry. Falls back to per-primitive
                // setGeometryAt otherwise.
                if (rebuildRenderableWithMorphs(instEntities[ei], bufferIndex))
                {
                    bufferIndex += primCount;
                    continue;
                }

                for (size_t pi = 0; pi < primCount && bufferIndex < totalBuffers; pi++)
                {
                    // Placeholder slots: skip — the gltfio-built geometry
                    // remains in place on this primitive.
                    if (!_preservedVertexBuffers[bufferIndex])
                    {
                        bufferIndex++;
                        continue;
                    }
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

    bool GltfSceneAsset::rebuildRenderableWithMorphs(utils::Entity entity, size_t slotStart)
    {
        auto &rm = _engine->getRenderableManager();
        auto ri = rm.getInstance(entity);
        if (!ri.isValid())
        {
            return false;
        }
        const size_t primCount = rm.getPrimitiveCount(ri);
        if (primCount == 0)
        {
            return false;
        }
        if (slotStart + primCount > _preservedVertexBuffers.size() ||
            slotStart + primCount > _preservedMorphInfos.size())
        {
            return false;
        }

        // Every primitive must have both rebuilt geometry and a slot in a
        // replacement morph buffer; a single gap means we cannot re-specify
        // the renderable without losing the gltfio-built geometry on that
        // primitive, so the caller falls back to setGeometryAt.
        for (size_t pi = 0; pi < primCount; pi++)
        {
            const size_t slot = slotStart + pi;
            if (!_preservedVertexBuffers[slot] || !_preservedIndexBuffers[slot])
            {
                return false;
            }
            if (!_preservedMorphInfos[slot].mtb)
            {
                return false;
            }
        }

        const PreservedMorphInfo &morphInfo = _preservedMorphInfos[slotStart];
        MorphTargetBuffer *mtb = morphInfo.mtb;
        const cgltf_node *node = morphInfo.node;

        // Capture the renderable's current state; Builder::build destroys and
        // replaces the component, so everything gltfio set must be re-applied.
        const Box boundingBox = rm.getAxisAlignedBoundingBox(ri);
        const bool culling = rm.isCullingEnabled(ri);
        const bool castShadows = rm.isShadowCaster(ri);
        const bool receiveShadows = rm.isShadowReceiver(ri);
        const bool screenSpaceContactShadows = rm.isScreenSpaceContactShadowsEnabled(ri);
        const uint8_t layerMask = rm.getLayerMask(ri);
        const uint8_t priority = rm.getPriority(ri);

        RenderableManager::Builder builder(primCount);
        for (size_t pi = 0; pi < primCount; pi++)
        {
            const size_t slot = slotStart + pi;
            builder.geometry(pi,
                             RenderableManager::PrimitiveType::TRIANGLES,
                             _preservedVertexBuffers[slot],
                             _preservedIndexBuffers[slot],
                             0, _preservedIndexCounts[slot]);
            builder.material(pi, rm.getMaterialInstanceAt(ri, pi));
            builder.blendOrder(pi, rm.getBlendOrderAt(ri, pi));
            builder.morphing(0, pi, _preservedMorphInfos[slot].vertexOffset);
        }
        for (unsigned int channel = 0; channel < 4; channel++)
        {
            builder.lightChannel(channel, rm.getLightChannel(ri, channel));
        }
        builder.boundingBox(boundingBox)
            .culling(culling)
            .castShadows(castShadows)
            .receiveShadows(receiveShadows)
            .screenSpaceContactShadows(screenSpaceContactShadows)
            .layerMask(0xFF, layerMask)
            .priority(priority);
        if (node && node->skin)
        {
            builder.skinning(node->skin->joints_count);
        }
        builder.morphing(mtb);
        builder.build(*_engine, entity);

        // gltfio seeds the renderable with the glTF default weights (mesh
        // weights overridden by node weights); the rebuild resets them to
        // zero, so re-apply. Mirrors AssetLoader's cap at 256 weights.
        auto newRi = rm.getInstance(entity);
        const cgltf_mesh *mesh = node ? node->mesh : nullptr;
        const size_t weightCount = std::min<size_t>(256, morphInfo.targetCount);
        std::vector<float> weights(weightCount, 0.0f);
        if (mesh)
        {
            const size_t c = std::min(weightCount, (size_t)mesh->weights_count);
            for (size_t i = 0; i < c; i++)
            {
                weights[i] = mesh->weights[i];
            }
        }
        if (node)
        {
            const size_t c = std::min(weightCount, (size_t)node->weights_count);
            for (size_t i = 0; i < c; i++)
            {
                weights[i] = node->weights[i];
            }
        }
        rm.setMorphWeights(newRi, weights.data(), weightCount);

        TRACE("rebuildRenderableWithMorphs: rebuilt renderable with %zu prims, "
              "%zu morph targets, morph vertex count from offset %zu",
              primCount, morphInfo.targetCount, morphInfo.vertexOffset);
        return true;
    }

    int GltfSceneAsset::getPrimitiveOffsetForEntity(utils::Entity entity) const
    {
        auto it = _entityToPrimitiveOffset.find(utils::Entity::smuggle(entity));
        if (it == _entityToPrimitiveOffset.end())
        {
            return -1; // Entity not found or has no preserved geometry
        }
        return it->second;
    }

    void GltfSceneAsset::setFlatShading(bool flatShading)
    {
        if (flatShading == _flatShading)
            return;
        _flatShading = flatShading;

        size_t count = _preservedVertexBuffers.size();
        for (size_t i = 0; i < count; i++)
        {
            // Placeholder slots (non-triangle prims, missing-mesh entities)
            // have no preserved vertex buffer or tangent BOs. Skip them —
            // their original gltfio geometry is unaffected by flat-shading
            // toggling because we never replaced it.
            if (!_preservedVertexBuffers[i])
                continue;
            auto *bo = flatShading ? _flatTangentBOs[i] : _smoothTangentBOs[i];
            _preservedVertexBuffers[i]->setBufferObjectAt(*_engine, 1, bo);
        }
    }

    size_t GltfSceneAsset::getBoneCount(size_t skinIndex) const
    {
        auto &instance = _instances.front();
        return instance->getBoneCount(skinIndex);
    }

    const utils::Entity *GltfSceneAsset::getBones(size_t skinIndex) const {
        auto &instance = _instances.front();
        return instance->getBones(skinIndex);
    }

    const char *GltfSceneAsset::getBoneName(size_t skinIndex, size_t boneIndex) const {
        auto &instance = _instances.front();
        return instance->getBoneName(skinIndex, boneIndex);
    }

} // namespace thermion
