
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
        uint32_t requiredGeometryCapabilities,
        MaterialInstance **materialInstances,
        size_t materialInstanceCount) : _asset(asset),
                                        _assetLoader(assetLoader),
                                        _engine(engine),
                                        _ncm(ncm),
                                        _materialInstances(materialInstances),
                                        _materialInstanceCount(materialInstanceCount)
    {
        const bool requiresUnwelded =
            (requiredGeometryCapabilities &
             (SCENE_ASSET_GEOMETRY_CAPABILITY_BARYCENTRICS |
              SCENE_ASSET_GEOMETRY_CAPABILITY_UNIQUE_TRIANGLE_CORNERS)) != 0;
        const bool requiresPreserved =
            (requiredGeometryCapabilities &
             (SCENE_ASSET_GEOMETRY_CAPABILITY_WRITABLE_VERTICES |
              SCENE_ASSET_GEOMETRY_CAPABILITY_PRESERVED_TOPOLOGY |
              SCENE_ASSET_GEOMETRY_CAPABILITY_ACCESSIBLE_GEOMETRY_BUFFERS)) != 0;

        if (requiresUnwelded)
        {
            if (rebuildVertexBuffers(false)) {
                _geometryCapabilities =
                    SCENE_ASSET_GEOMETRY_CAPABILITY_BARYCENTRICS |
                    SCENE_ASSET_GEOMETRY_CAPABILITY_ACCESSIBLE_GEOMETRY_BUFFERS |
                    SCENE_ASSET_GEOMETRY_CAPABILITY_UNIQUE_TRIANGLE_CORNERS;
                _supportsFlatShading = true;
            }
        }
        else if (requiresPreserved)
        {
            if (rebuildVertexBuffers(true)) {
                _geometryCapabilities =
                    SCENE_ASSET_GEOMETRY_CAPABILITY_WRITABLE_VERTICES |
                    SCENE_ASSET_GEOMETRY_CAPABILITY_ACCESSIBLE_GEOMETRY_BUFFERS |
                    SCENE_ASSET_GEOMETRY_CAPABILITY_PRESERVED_TOPOLOGY;
            }
        }
        for (int i = 0; i < asset->getAssetInstanceCount(); i++)
        {
            createInstance();
        }
        TRACE("Created GltfSceneAsset from FilamentAsset %d with %d reserved instances", asset, asset->getAssetInstanceCount());
    }

    bool GltfSceneAsset::supportsRequiredGeometryCapabilities(uint32_t requiredGeometryCapabilities)
    {
        constexpr uint32_t supported =
            SCENE_ASSET_GEOMETRY_CAPABILITY_BARYCENTRICS |
            SCENE_ASSET_GEOMETRY_CAPABILITY_WRITABLE_VERTICES |
            SCENE_ASSET_GEOMETRY_CAPABILITY_ACCESSIBLE_GEOMETRY_BUFFERS |
            SCENE_ASSET_GEOMETRY_CAPABILITY_PRESERVED_TOPOLOGY |
            SCENE_ASSET_GEOMETRY_CAPABILITY_UNIQUE_TRIANGLE_CORNERS;
        if ((requiredGeometryCapabilities & ~supported) != 0)
        {
            return false;
        }

        const bool requiresUnwelded =
            (requiredGeometryCapabilities &
             (SCENE_ASSET_GEOMETRY_CAPABILITY_BARYCENTRICS |
              SCENE_ASSET_GEOMETRY_CAPABILITY_UNIQUE_TRIANGLE_CORNERS)) != 0;
        const bool requiresPreservedTopology =
            (requiredGeometryCapabilities &
             (SCENE_ASSET_GEOMETRY_CAPABILITY_WRITABLE_VERTICES |
              SCENE_ASSET_GEOMETRY_CAPABILITY_PRESERVED_TOPOLOGY)) != 0;
        return !(requiresUnwelded && requiresPreservedTopology);
    }

    GltfSceneAsset::~GltfSceneAsset()
    {
        _instances.clear();
        for (auto *vb : _preservedVertexBuffers)
        {
            if (vb) _engine->destroy(vb);
        }
        for (auto *ib : _preservedIndexBuffers)
        {
            if (ib) _engine->destroy(ib);
        }
        for (auto *bo : _preservedBufferObjects)
        {
            if (bo) _engine->destroy(bo);
        }
        for (auto *bo : _smoothTangentBOs)
        {
            if (bo) _engine->destroy(bo);
        }
        for (auto *bo : _flatTangentBOs)
        {
            if (bo) _engine->destroy(bo);
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

    bool GltfSceneAsset::rebuildVertexBuffers(bool preserveTopology)
    {
        const bool preserveSourceTopology = preserveTopology;
        auto *sourceData = (const cgltf_data *)_asset->getSourceAsset();
        if (!sourceData)
        {
            Log("rebuildVertexBuffers: source data already released");
            return false;
        }

        if (_geometryPreserved)
        {
            Log("rebuildVertexBuffers: already called");
            return false;
        }

        std::vector<MeshEntry> meshEntries;
        collectAllMeshEntries(sourceData, meshEntries);

        // Use the root asset's getEntities() to match what getChildEntities() returns.
        // This ensures the entity enumeration order is consistent between rebuild
        // and queries.
        auto *allEntities = _asset->getEntities();
        size_t allEntityCount = _asset->getEntityCount();
        auto &rm = _engine->getRenderableManager();
        bool allPrimitivesRebuilt = true;
        size_t rebuiltPrimitiveCount = 0;

        auto appendPlaceholder = [&]() {
            _preservedVertexBuffers.push_back(nullptr);
            _preservedVertexBufferStorageModes.push_back(VERTEX_BUFFER_STORAGE_MODE_UNKNOWN);
            _preservedIndexBuffers.push_back(nullptr);
            _preservedIndexCounts.push_back(0);
            _smoothTangentBOs.push_back(nullptr);
            _flatTangentBOs.push_back(nullptr);
            allPrimitivesRebuilt = false;
        };

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
                        appendPlaceholder();
                    }
                    continue;
                }
            }

            const size_t renderablePrimitiveCount = rm.getPrimitiveCount(ri);
            if (mesh->primitives_count != renderablePrimitiveCount)
            {
                allPrimitivesRebuilt = false;
                TRACE("rebuildVertexBuffers: mesh/renderable primitive count mismatch at entity %zu (%zu vs %zu)",
                      ei, static_cast<size_t>(mesh->primitives_count), renderablePrimitiveCount);
            }
            for (size_t pi = 0; pi < renderablePrimitiveCount; pi++)
            {
                if (pi >= mesh->primitives_count)
                {
                    appendPlaceholder();
                    continue;
                }
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
                    appendPlaceholder();
                    continue;
                }

                // --- Find accessors for all attributes ---
                const cgltf_accessor *posAccessor = nullptr;
                const cgltf_accessor *nrmAccessor = nullptr;
                const cgltf_accessor *tanAccessor = nullptr;
                const cgltf_accessor *uvAccessor = nullptr;
                const cgltf_accessor *uv1Accessor = nullptr;
                const cgltf_accessor *colorAccessor = nullptr;
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
                        if (prim.attributes[ai].index == 0)
                            uvAccessor = prim.attributes[ai].data;
                        else if (prim.attributes[ai].index == 1)
                            uv1Accessor = prim.attributes[ai].data;
                        break;
                    case cgltf_attribute_type_color:
                        if (prim.attributes[ai].index == 0)
                            colorAccessor = prim.attributes[ai].data;
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
                if (!posAccessor) {
                    appendPlaceholder();
                    continue;
                }

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

                if (indices.size() < 3 || indices.size() % 3 != 0) {
                    appendPlaceholder();
                    continue;
                }
                bool indicesInRange = true;
                for (const auto index : indices) {
                    if (index >= posAccessor->count) {
                        indicesInRange = false;
                        break;
                    }
                }
                if (!indicesInRange) {
                    appendPlaceholder();
                    continue;
                }

                uint32_t triangleCount = (uint32_t)(indices.size() / 3);
                uint32_t newVertexCount = preserveSourceTopology
                                              ? (uint32_t)posAccessor->count
                                              : triangleCount * 3;

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

                std::vector<float> srcUV1s;
                size_t uv1Components = 0;
                if (uv1Accessor)
                {
                    uv1Components = cgltf_num_components(uv1Accessor->type);
                    srcUV1s.resize(uv1Accessor->count * uv1Components);
                    cgltf_accessor_unpack_floats(uv1Accessor, srcUV1s.data(), srcUV1s.size());
                }

                std::vector<float> srcColors;
                size_t colorComponents = 0;
                if (colorAccessor)
                {
                    colorComponents = cgltf_num_components(colorAccessor->type);
                    srcColors.resize(colorAccessor->count * colorComponents);
                    cgltf_accessor_unpack_floats(colorAccessor, srcColors.data(), srcColors.size());
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

                // Copy source vertices directly for editable geometry, or
                // duplicate them per triangle for barycentric wireframes.
                std::vector<float> newPositions(newVertexCount * 3);
                std::vector<float> newNormals(newVertexCount * 3);
                std::vector<float> newTangents; // float4 (xyz=tangent, w=sign)
                if (tanAccessor)
                {
                    newTangents.resize(newVertexCount * 4);
                }
                std::vector<float> newUVs(newVertexCount * 2);
                std::vector<float> newUV1s;
                if (uv1Accessor)
                {
                    newUV1s.resize(newVertexCount * 2);
                }
                std::vector<float> newColors(newVertexCount * 4, 1.0f);
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

                for (uint32_t dstIdx = 0; dstIdx < newVertexCount; dstIdx++)
                {
                    uint32_t srcIdx = preserveSourceTopology ? dstIdx : indices[dstIdx];

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

                    // Secondary UV
                    if (uv1Accessor && srcIdx < uv1Accessor->count)
                    {
                        newUV1s[dstIdx * 2 + 0] = srcUV1s[srcIdx * uv1Components + 0];
                        newUV1s[dstIdx * 2 + 1] = srcUV1s[srcIdx * uv1Components + 1];
                    }

                    // Vertex color
                    if (colorAccessor && srcIdx < colorAccessor->count)
                    {
                        const size_t sourceOffset = srcIdx * colorComponents;
                        newColors[dstIdx * 4 + 0] = srcColors[sourceOffset + 0];
                        newColors[dstIdx * 4 + 1] = srcColors[sourceOffset + 1];
                        newColors[dstIdx * 4 + 2] = srcColors[sourceOffset + 2];
                        newColors[dstIdx * 4 + 3] = colorComponents >= 4
                            ? srcColors[sourceOffset + 3]
                            : 1.0f;
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
                    if (!preserveSourceTopology)
                    {
                        const int corner = dstIdx % 3;
                        newBarycentrics[dstIdx * 4 + 0] = bary[corner][0];
                        newBarycentrics[dstIdx * 4 + 1] = bary[corner][1];
                        newBarycentrics[dstIdx * 4 + 2] = bary[corner][2];
                        newBarycentrics[dstIdx * 4 + 3] = bary[corner][3];
                    }

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
                    for (uint32_t i = 0; i < triangleCount; i++)
                    {
                        tris[i] = preserveSourceTopology
                                      ? filament::math::uint3{indices[i * 3], indices[i * 3 + 1], indices[i * 3 + 2]}
                                      : filament::math::uint3{i * 3, i * 3 + 1, i * 3 + 2};
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
                // Flat shading requires per-face vertices. Editable geometry
                // preserves shared vertices, so its flat buffer intentionally
                // matches the smooth buffer.
                std::vector<filament::math::short4> flatTangentQuats;
                if (preserveSourceTopology)
                {
                    flatTangentQuats = smoothTangentQuats;
                }
                else
                {
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
                    flatTangentQuats.resize(newVertexCount);
                    flatOrientation->getQuats(flatTangentQuats.data(), newVertexCount);
                    delete flatOrientation;
                }

                // --- Build VertexBuffer ---
                // Buffer layout: POSITION(0), TANGENTS(1), UV0(2), CUSTOM0(3),
                // COLOR(4), [UV1], [BONE_INDICES, BONE_WEIGHTS].
                const uint8_t uv1BufferIndex = 5;
                const uint8_t boneIndicesBufferIndex = uv1Accessor ? 6 : 5;
                const uint8_t boneWeightsBufferIndex = boneIndicesBufferIndex + 1;
                uint8_t bufferCount = 5 + (uv1Accessor ? 1 : 0) + (hasSkinning ? 2 : 0);

                auto vbBuilder = VertexBuffer::Builder()
                                     .vertexCount(newVertexCount)
                                     .bufferCount(bufferCount);

                // Unwelded geometry swaps BufferObjects at runtime to toggle
                // between smooth and flat tangent frames. Editable geometry,
                // on the other hand, must remain writable through the public
                // VertexBuffer::setBufferAt API, which is incompatible with
                // BufferObject-backed streams.
                if (!preserveSourceTopology)
                {
                    vbBuilder.enableBufferObjects();
                }

                vbBuilder
                    .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                    .attribute(VertexAttribute::TANGENTS, 1, VertexBuffer::AttributeType::SHORT4)
                    .normalized(VertexAttribute::TANGENTS)
                    .attribute(VertexAttribute::UV0, 2, VertexBuffer::AttributeType::FLOAT2)
                    .attribute(VertexAttribute::CUSTOM0, 3, VertexBuffer::AttributeType::FLOAT4)
                    .attribute(VertexAttribute::COLOR, 4, VertexBuffer::AttributeType::FLOAT4);

                if (uv1Accessor)
                {
                    vbBuilder.attribute(VertexAttribute::UV1, uv1BufferIndex,
                                        VertexBuffer::AttributeType::FLOAT2);
                }

                if (hasSkinning)
                {
                    vbBuilder
                        .attribute(VertexAttribute::BONE_INDICES, boneIndicesBufferIndex, VertexBuffer::AttributeType::UBYTE4)
                        .attribute(VertexAttribute::BONE_WEIGHTS, boneWeightsBufferIndex, VertexBuffer::AttributeType::FLOAT4);
                }

                VertexBuffer *vb = vbBuilder.build(*_engine);
                auto uploadDirect = [&](uint8_t bufferIndex, const void *source, size_t size)
                {
                    auto *data = new uint8_t[size];
                    memcpy(data, source, size);
                    vb->setBufferAt(*_engine, bufferIndex,
                                    VertexBuffer::BufferDescriptor(data, size, FREE_CB));
                };

                auto uploadStream = [&](uint8_t bufferIndex, const void *source, size_t size)
                {
                    if (preserveSourceTopology)
                    {
                        uploadDirect(bufferIndex, source, size);
                        return;
                    }

                    auto *data = new uint8_t[size];
                    memcpy(data, source, size);
                    BufferObject *bo = BufferObject::Builder().size(size).build(*_engine);
                    bo->setBuffer(*_engine, BufferObject::BufferDescriptor(data, size, FREE_CB));
                    vb->setBufferObjectAt(*_engine, bufferIndex, bo);
                    _preservedBufferObjects.push_back(bo);
                };

                // Buffer 0: POSITION
                size_t posDataSize = newVertexCount * 3 * sizeof(float);
                uploadStream(0, newPositions.data(), posDataSize);

                // Buffer 1: TANGENTS (SHORT4 quantized quaternions, matching gltfio's format)
                // Create both smooth and flat tangent BOs for runtime toggling.
                size_t tangDataSize = newVertexCount * sizeof(filament::math::short4);

                if (preserveSourceTopology)
                {
                    uploadDirect(1, smoothTangentQuats.data(), tangDataSize);
                    _smoothTangentBOs.push_back(nullptr);
                    _flatTangentBOs.push_back(nullptr);
                }
                else
                {
                    auto *smoothTangData = new uint8_t[tangDataSize];
                    memcpy(smoothTangData, smoothTangentQuats.data(), tangDataSize);
                    BufferObject *smoothTangBO = BufferObject::Builder().size(tangDataSize).build(*_engine);
                    smoothTangBO->setBuffer(*_engine, BufferObject::BufferDescriptor(smoothTangData, tangDataSize, FREE_CB));

                    auto *flatTangData = new uint8_t[tangDataSize];
                    memcpy(flatTangData, flatTangentQuats.data(), tangDataSize);
                    BufferObject *flatTangBO = BufferObject::Builder().size(tangDataSize).build(*_engine);
                    flatTangBO->setBuffer(*_engine, BufferObject::BufferDescriptor(flatTangData, tangDataSize, FREE_CB));

                    // Bind smooth by default.
                    vb->setBufferObjectAt(*_engine, 1, smoothTangBO);
                    _smoothTangentBOs.push_back(smoothTangBO);
                    _flatTangentBOs.push_back(flatTangBO);
                }

                // Buffer 2: UV0
                size_t uvDataSize = newVertexCount * 2 * sizeof(float);
                uploadStream(2, newUVs.data(), uvDataSize);

                // Buffer 3: CUSTOM0 (barycentrics)
                size_t baryDataSize = newVertexCount * 4 * sizeof(float);
                uploadStream(3, newBarycentrics.data(), baryDataSize);

                // Buffer 4: COLOR (source COLOR_0 or white when absent)
                size_t colorDataSize = newVertexCount * 4 * sizeof(float);
                uploadStream(4, newColors.data(), colorDataSize);

                if (uv1Accessor)
                {
                    const size_t uv1DataSize = newVertexCount * 2 * sizeof(float);
                    uploadStream(uv1BufferIndex, newUV1s.data(), uv1DataSize);
                }

                if (hasSkinning)
                {
                    // Buffer 5: BONE_INDICES
                    size_t jointDataSize = newVertexCount * 4 * sizeof(uint8_t);
                    uploadStream(boneIndicesBufferIndex, newJoints.data(), jointDataSize);

                    // Buffer 6: BONE_WEIGHTS
                    size_t weightDataSize = newVertexCount * 4 * sizeof(float);
                    uploadStream(boneWeightsBufferIndex, newWeights.data(), weightDataSize);
                }

                // Editable geometry retains source indices. Unwelded geometry
                // uses a sequential index buffer.
                const size_t newIndexCount = preserveSourceTopology ? indices.size() : newVertexCount;
                size_t indexDataSize = newIndexCount * sizeof(uint32_t);
                auto *newIndices = new uint8_t[indexDataSize];
                auto *indexPtr = reinterpret_cast<uint32_t *>(newIndices);
                for (uint32_t i = 0; i < newIndexCount; i++)
                {
                    indexPtr[i] = preserveSourceTopology ? indices[i] : i;
                }

                IndexBuffer *ib = IndexBuffer::Builder()
                                      .indexCount(newIndexCount)
                                      .bufferType(IndexBuffer::IndexType::UINT)
                                      .build(*_engine);
                ib->setBuffer(*_engine,
                              IndexBuffer::BufferDescriptor(newIndices, indexDataSize, FREE_CB));

                // --- Replace geometry on the renderable ---
                rm.setGeometryAt(ri, pi,
                                 RenderableManager::PrimitiveType::TRIANGLES,
                                 vb, ib, 0, newIndexCount);

                _preservedVertexBuffers.push_back(vb);
                _preservedVertexBufferStorageModes.push_back(
                    preserveSourceTopology
                        ? VERTEX_BUFFER_STORAGE_MODE_DIRECT
                        : VERTEX_BUFFER_STORAGE_MODE_BUFFER_OBJECTS);
                _preservedIndexBuffers.push_back(ib);
                _preservedIndexCounts.push_back(newIndexCount);
                rebuiltPrimitiveCount++;

                TRACE("rebuildVertexBuffers: primitive %zu %s with %u vertices and %zu indices (skinned=%d)",
                      pi, preserveSourceTopology ? "preserved topology" : "unwelded",
                      newVertexCount, newIndexCount, hasSkinning);
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

        _geometryPreserved = rebuiltPrimitiveCount > 0;
        return allPrimitivesRebuilt && rebuiltPrimitiveCount > 0;
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
        if (!_supportsFlatShading)
        {
            Log("setFlatShading called on an asset without flat-shading support");
            return;
        }
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
            if (!bo)
                continue;
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
