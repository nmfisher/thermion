
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

#include <utils/NameComponentManager.h>

#include "scene/GltfSceneAssetInstance.hpp"
#include "scene/SceneAsset.hpp"

namespace thermion
{

    GltfSceneAsset::GltfSceneAsset(
        gltfio::FilamentAsset *asset,
        gltfio::AssetLoader *assetLoader,
        Engine *engine,
        utils::NameComponentManager* ncm,
        MaterialInstance **materialInstances,
        size_t materialInstanceCount) : _asset(asset),
                                  _assetLoader(assetLoader),
                                  _engine(engine),
                                  _ncm(ncm),
                                  _materialInstances(materialInstances),
                                  _materialInstanceCount(materialInstanceCount)
    {
        for(int i = 0; i < asset->getAssetInstanceCount(); i++) {
            createInstance();
        }
        TRACE("Created GltfSceneAsset from FilamentAsset %d with %d reserved instances", asset, asset->getAssetInstanceCount());
    }

    GltfSceneAsset::~GltfSceneAsset()
    {
        _instances.clear();
        for (auto* vb : _wireframeVertexBuffers) {
            _engine->destroy(vb);
        }
        for (auto* ib : _wireframeIndexBuffers) {
            _engine->destroy(ib);
        }
        for (auto* bo : _wireframeBufferObjects) {
            _engine->destroy(bo);
        }
        releaseSourceData();
        _assetLoader->destroyAsset(_asset);
    }

    void GltfSceneAsset::releaseSourceData() {
        if (!_sourceDataReleased) {
            _asset->releaseSourceData();
            _sourceDataReleased = true;
        }
    }

    void GltfSceneAsset::destroyInstance(SceneAsset *asset) {
        for(auto& instance : _instances) {
            if(instance.get() == asset) {
                instance->inUse = false;
                return;
            }
        }
    };


    SceneAsset *GltfSceneAsset::createInstance(MaterialInstance **materialInstances, size_t materialInstanceCount)
    {

        // first, see if we can recycle any "unused" instances.
        for(auto &instance : _instances) {
            if(!instance->inUse) {
                instance->inUse = true;
                return instance.get();
            }
        }

        if(_instances.size() == _asset->getAssetInstanceCount())
        {
            TRACE("Warning: %d pre-allocated instances already consumed. A new instance will be allocated internally, but in future you may wish to pre-allocate a larger number.",
                _asset->getAssetInstanceCount()
            );
            _assetLoader->createInstance(_asset);
        } else {
            TRACE("Returning pre-allocated instance at index %d", _instances.size());
        }

        auto instance = _asset->getAssetInstances()[_instances.size()];

        instance->recomputeBoundingBoxes();
        auto bb = instance->getBoundingBox();
        TRACE("Instance bounding box center (%f,%f,%f), extent (%f,%f,%f)", bb.center().x, bb.center().y, bb.center().z, bb.extent().x,bb.extent().y,bb.extent().z);
        instance->getAnimator()->updateBoneMatrices();

        auto& rm = _engine->getRenderableManager();

        if(materialInstanceCount > 0) {

            TRACE("Instance entity count : %d", instance->getEntityCount());

            for(int i = 0; i < instance->getEntityCount(); i++) {
                auto renderableInstance = rm.getInstance(instance->getEntities()[i]);
                if(!renderableInstance.isValid()) {
                    TRACE("Instance child entity %d not renderable", i);
                } else {
                    TRACE("Instance child entity %d renderable", i);
                    for(int j = 0; j < materialInstanceCount; j++) {
                        rm.setMaterialInstanceAt(renderableInstance, i, materialInstances[j]);
                    }
                }
            }
        }

        std::unique_ptr<GltfSceneAssetInstance> sceneAssetInstance = std::make_unique<GltfSceneAssetInstance>(
            this,
            instance,
            _engine,
            _ncm,
            materialInstances,
            materialInstanceCount
        );

        auto *raw = sceneAssetInstance.get();

        _instances.push_back(std::move(sceneAssetInstance));
        return raw;
    }

    static const auto FREE_CB = [](void* mem, size_t, void*) { free(mem); };

    // Build a map from node/mesh name to cgltf_mesh for all nodes in the asset.
    // Multiple nodes can reference the same mesh, so we also build a flat list
    // of (name, mesh) pairs to handle unnamed nodes by index.
    struct MeshEntry {
        const char* name;       // node name (may be null)
        const char* meshName;   // mesh name (may be null)
        const cgltf_mesh* mesh;
    };

    static void collectAllMeshEntries(const cgltf_data* data, std::vector<MeshEntry>& entries) {
        for (cgltf_size i = 0; i < data->nodes_count; i++) {
            const cgltf_node& node = data->nodes[i];
            if (node.mesh) {
                entries.push_back({node.name, node.mesh->name, node.mesh});
            }
        }
    }

    // Find the cgltf_mesh for a given renderable entity by matching names.
    static const cgltf_mesh* findMeshForEntity(
        utils::Entity entity,
        utils::NameComponentManager* ncm,
        const std::vector<MeshEntry>& meshEntries)
    {
        auto ni = ncm->getInstance(entity);
        if (!ni.isValid()) return nullptr;

        auto entityName = ncm->getName(ni);
        if (!entityName || strlen(entityName) == 0) return nullptr;

        // Match against node name first, then mesh name
        for (const auto& entry : meshEntries) {
            if (entry.name && strcmp(entry.name, entityName) == 0) {
                return entry.mesh;
            }
            if (entry.meshName && strcmp(entry.meshName, entityName) == 0) {
                return entry.mesh;
            }
        }
        return nullptr;
    }

    void GltfSceneAsset::applyWireframeBarycentrics()
    {
        auto* sourceData = (const cgltf_data*)_asset->getSourceAsset();
        if (!sourceData) {
            Log("applyWireframeBarycentrics: source data already released");
            return;
        }

        // Build a lookup of all cgltf nodes that have meshes
        std::vector<MeshEntry> meshEntries;
        collectAllMeshEntries(sourceData, meshEntries);

        const auto* renderableEntities = _asset->getRenderableEntities();
        size_t renderableCount = _asset->getRenderableEntityCount();
        auto& rm = _engine->getRenderableManager();

        for (size_t ei = 0; ei < renderableCount; ei++) {
            auto entity = renderableEntities[ei];
            auto ri = rm.getInstance(entity);
            if (!ri.isValid()) continue;

            const cgltf_mesh* mesh = findMeshForEntity(entity, _ncm, meshEntries);
            if (!mesh) {
                TRACE("applyWireframeBarycentrics: no cgltf mesh found for entity %zu", ei);
                continue;
            }

            for (cgltf_size pi = 0; pi < mesh->primitives_count; pi++) {
                const cgltf_primitive& prim = mesh->primitives[pi];

                // Only handle triangle primitives
                if (prim.type != cgltf_primitive_type_triangles) {
                    TRACE("applyWireframeBarycentrics: skipping non-triangle primitive");
                    continue;
                }

                // --- Read indices ---
                std::vector<uint32_t> indices;
                if (prim.indices) {
                    indices.resize(prim.indices->count);
                    for (cgltf_size i = 0; i < prim.indices->count; i++) {
                        indices[i] = (uint32_t)cgltf_accessor_read_index(prim.indices, i);
                    }
                } else {
                    // No index buffer - generate trivial indices
                    if (prim.attributes_count > 0) {
                        cgltf_size vertexCount = prim.attributes[0].data->count;
                        indices.resize(vertexCount);
                        for (cgltf_size i = 0; i < vertexCount; i++) {
                            indices[i] = (uint32_t)i;
                        }
                    }
                }

                if (indices.size() < 3 || indices.size() % 3 != 0) continue;

                uint32_t triangleCount = (uint32_t)(indices.size() / 3);
                uint32_t newVertexCount = triangleCount * 3;

                // --- Read position data ---
                const cgltf_accessor* posAccessor = nullptr;
                for (cgltf_size ai = 0; ai < prim.attributes_count; ai++) {
                    if (prim.attributes[ai].type == cgltf_attribute_type_position) {
                        posAccessor = prim.attributes[ai].data;
                        break;
                    }
                }
                if (!posAccessor) continue;

                // Unpack all positions as floats
                size_t posComponents = cgltf_num_components(posAccessor->type);
                std::vector<float> srcPositions(posAccessor->count * posComponents);
                cgltf_accessor_unpack_floats(posAccessor, srcPositions.data(), srcPositions.size());

                // --- Unweld: duplicate vertices per triangle ---
                size_t posDataSize = newVertexCount * 3 * sizeof(float);
                float* newPositions = (float*)malloc(posDataSize);

                size_t baryDataSize = newVertexCount * 4 * sizeof(float);
                float* newBarycentrics = (float*)malloc(baryDataSize);

                // Barycentric coordinate patterns
                const float bary[3][4] = {
                    {1.0f, 0.0f, 0.0f, 0.0f},
                    {0.0f, 1.0f, 0.0f, 0.0f},
                    {0.0f, 0.0f, 1.0f, 0.0f}
                };

                for (uint32_t t = 0; t < triangleCount; t++) {
                    for (int v = 0; v < 3; v++) {
                        uint32_t srcIdx = indices[t * 3 + v];
                        uint32_t dstIdx = t * 3 + v;

                        // Copy position (3 floats)
                        newPositions[dstIdx * 3 + 0] = srcPositions[srcIdx * posComponents + 0];
                        newPositions[dstIdx * 3 + 1] = srcPositions[srcIdx * posComponents + 1];
                        newPositions[dstIdx * 3 + 2] = srcPositions[srcIdx * posComponents + 2];

                        // Assign barycentric
                        newBarycentrics[dstIdx * 4 + 0] = bary[v][0];
                        newBarycentrics[dstIdx * 4 + 1] = bary[v][1];
                        newBarycentrics[dstIdx * 4 + 2] = bary[v][2];
                        newBarycentrics[dstIdx * 4 + 3] = bary[v][3];
                    }
                }

                // --- Build sequential index data ---
                size_t indexDataSize = newVertexCount * sizeof(uint32_t);
                uint32_t* newIndices = (uint32_t*)malloc(indexDataSize);
                for (uint32_t i = 0; i < newVertexCount; i++) {
                    newIndices[i] = i;
                }

                // --- Build new VertexBuffer with POSITION + CUSTOM0 ---
                VertexBuffer* vb = VertexBuffer::Builder()
                    .vertexCount(newVertexCount)
                    .bufferCount(2)
                    .enableBufferObjects()
                    .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
                    .attribute(VertexAttribute::CUSTOM0, 1, VertexBuffer::AttributeType::FLOAT4)
                    .build(*_engine);

                // Upload position data via BufferObject
                BufferObject* posBO = BufferObject::Builder()
                    .size(posDataSize)
                    .build(*_engine);
                posBO->setBuffer(*_engine,
                    BufferObject::BufferDescriptor(newPositions, posDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 0, posBO);

                // Upload barycentric data via BufferObject
                BufferObject* baryBO = BufferObject::Builder()
                    .size(baryDataSize)
                    .build(*_engine);
                baryBO->setBuffer(*_engine,
                    BufferObject::BufferDescriptor(newBarycentrics, baryDataSize, FREE_CB));
                vb->setBufferObjectAt(*_engine, 1, baryBO);

                // --- Build new IndexBuffer ---
                IndexBuffer* ib = IndexBuffer::Builder()
                    .indexCount(newVertexCount)
                    .bufferType(IndexBuffer::IndexType::UINT)
                    .build(*_engine);

                ib->setBuffer(*_engine,
                    IndexBuffer::BufferDescriptor(newIndices, indexDataSize, FREE_CB));

                // --- Replace geometry on the renderable ---
                rm.setGeometryAt(ri, pi,
                    RenderableManager::PrimitiveType::TRIANGLES,
                    vb, ib, 0, newVertexCount);

                // Track for cleanup
                _wireframeVertexBuffers.push_back(vb);
                _wireframeIndexBuffers.push_back(ib);
                _wireframeBufferObjects.push_back(posBO);
                _wireframeBufferObjects.push_back(baryBO);

                TRACE("applyWireframeBarycentrics: primitive %zu unwelded %zu -> %u vertices",
                      pi, indices.size(), newVertexCount);
            }
        }
    }

}
