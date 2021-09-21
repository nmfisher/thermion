/*
 * Copyright (C) 2021 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "GPUMorphHelper.h"

#include <backend/BufferDescriptor.h>
#include <filament/BufferObject.h>
#include <filament/RenderableManager.h>
#include <filament/VertexBuffer.h>
#include <filamat/Package.h>
#include <filamat/MaterialBuilder.h>
#include <filament/Color.h>

#include "GltfEnums.h"
#include "TangentsJob.h"

#include <iostream>

#include <math.h>

using namespace filament;
using namespace filamat;
using namespace filament::math;
using namespace utils;
namespace gltfio {

    static constexpr uint8_t kUnused = 0xff;

    uint32_t computeBindingSize(const cgltf_accessor *accessor);

    uint32_t computeBindingSize(const cgltf_accessor *accessor);

    uint32_t computeBindingOffset(const cgltf_accessor *accessor);

    static const auto FREE_CALLBACK = [](void *mem, size_t s, void *) {
        free(mem);
    };

    GPUMorphHelper::GPUMorphHelper(FFilamentAsset *asset, const char* meshName, int primitiveIndex) : mAsset(asset), mPrimitiveIndex(primitiveIndex) {

        cgltf_size num_primitives = 0;
        NodeMap &sourceNodes = asset->isInstanced() ? asset->mInstances[0]->nodeMap
                                                  : asset->mNodeMap;

        for (auto pair : sourceNodes) {
            cgltf_node const *node = pair.first;
            cgltf_mesh const *mesh = node->mesh;

            if (mesh) {
                std::cout << "Mesh " << mesh->name <<std::endl;
                if(strcmp(meshName, mesh->name) == 0) {
                  targetMesh = mesh;
                  num_primitives = mesh->primitives_count;
                  addPrimitive(mesh);
                }
            }
        }
        auto materialInstances = mAsset->getMaterialInstances();

        std::cout << "MaterialInstances in asset:" << std::endl;
        for(int i = 0; i < mAsset->getMaterialInstanceCount(); i++) {
          const char* name = materialInstances[i]->getName();
          std::cout << "Material : " << name << std::endl;
        }
    
        createTextures();
          
    }

    GPUMorphHelper::~GPUMorphHelper() {

    }

    ///
    /// Creates the texture that will store the morphable attributes. The texture will be sized according to the total number of vertices in the mesh, meaning all primitives share the same texture.
    ///
    void GPUMorphHelper::createTextures() {
        auto materialInstances = mAsset->getMaterialInstances();
        auto &engine = *(mAsset->mEngine);
      
        auto& prim = animatedPrimitive;

        // for a single morph target, each vertex will be assigned 2 pixels, corresponding to a position vec3 and a normal vec3
        // these two vectors will be laid out adjacent in memory
        // the total texture "width" is the total number of these pixels
        // morph targets are then assigned to the depth channel
        auto textureWidth = prim->numVertices * 2;

        // the total size of the texture in bytes
        // equal to (numVertices * numAttributes * vectorSize (3) * sizeof(float) * numMorphTargets)
        auto textureSize = textureWidth * 3 * sizeof(float) * prim->numTargets;
        auto textureBuffer = (float *const) malloc(textureSize);
    
        if(!textureBuffer) {
          std::cout << "Error allocating texture buffer" << std::endl;
          exit(-1);
        }
      
        uint32_t offset = 0;
      
        // assume the primitive morph target source buffer is laid out like:
        // |target0_v0_pos * 3|target0_v0_norm * 3|target0_v1_pos * 3|target0_v1_norm * 3|...|target1_v0_pos * 3|target1_v0_norm * 3|target1_v1_pos * 3|target1_v1_norm * 3|...
        // where:
        // - target0/target1/etc is the first/second/etc morph target
        // - v0/v1/etc is the first/second/etc vertex
        // - pos/norm are each 3-float vectors
        for (auto &target : prim->targets) {
            if(target.type == cgltf_attribute_type_position
            || target.type == cgltf_attribute_type_normal
            ) {
                memcpy(textureBuffer+offset, target.bufferObject, target.bufferSize);
                offset += int(target.bufferSize / sizeof(float));
            }
        }
      
        Texture* texture = Texture::Builder()
              .width(textureWidth) //
              .height(1)
              .depth(prim->numTargets)
              .sampler(Texture::Sampler::SAMPLER_2D_ARRAY)
              .format(Texture::InternalFormat::RGB32F)
              .levels(0x01)
              .build(engine);
        
        prim->texture = texture; //std::unique_ptr<Texture>(texture);

        Texture::PixelBufferDescriptor descriptor(
                textureBuffer,
                textureSize,
                Texture::Format::RGB,
                Texture::Type::FLOAT,
                FREE_CALLBACK,
                nullptr);
        prim->texture->setImage(engine, 0, 0,0, 0, textureWidth, 1, prim->numTargets, std::move(descriptor));
      
        for(int i = 0; i < mAsset->getMaterialInstanceCount(); i++) {
            const char* name = materialInstances[i]->getName();
            if(strcmp(name, prim->materialName) == 0) {
                std::cout << "Found material instance for primitive under name : " << name << std::endl;
                prim->materialInstance = materialInstances[i]; //std::unique_ptr<MaterialInstance>(materialInstances[i]);
                break;
            }
        }
      
        if(!prim->materialInstance) {
          exit(-1);
        }

        prim->materialInstance->setParameter("dimensions", filament::math::int3 { prim->numVertices * 2, numAttributes, prim->numTargets });
        prim->materialInstance->setParameter("morphTargets", prim->texture, TextureSampler());
        float weights[prim->numTargets];
        memset(weights, 0, prim->numTargets * sizeof(float));
        prim->materialInstance->setParameter("morphTargetWeights", weights, prim->numTargets);
    }

    void GPUMorphHelper::applyWeights(float const *weights, size_t count) noexcept {
      std::cout << "Applying " << count << " weights " << std::endl;
      animatedPrimitive->materialInstance->setParameter("morphTargetWeights", weights, count);
    }

    void
    GPUMorphHelper::addPrimitive(cgltf_mesh const *mesh) {
        auto &engine = *mAsset->mEngine;
        const cgltf_primitive &prim = mesh->primitives[mPrimitiveIndex];
      
        const auto &gltfioPrim = mAsset->mMeshCache.at(mesh)[mPrimitiveIndex];
        VertexBuffer *vertexBuffer = gltfioPrim.vertices;

        animatedPrimitive = std::make_unique<GltfPrimitive>(GltfPrimitive{vertexBuffer});

        animatedPrimitive->materialName = prim.material->name;
        animatedPrimitive->numTargets = prim.targets_count;
        animatedPrimitive->numVertices = vertexBuffer->getVertexCount();
        cgltf_size maxIndex = 0;
        for(int i = 0; i < prim.indices->count; i++) {
          maxIndex = std::max(cgltf_accessor_read_index(prim.indices, i), maxIndex);
        }

        const cgltf_accessor *previous = nullptr;

        // iterate over every target for the primitive, 
        for (int targetIndex = 0; targetIndex < prim.targets_count; targetIndex++) {
            const cgltf_morph_target &morphTarget = prim.targets[targetIndex];
            for (cgltf_size aindex = 0; aindex < morphTarget.attributes_count; aindex++) {
                const cgltf_attribute &attribute = morphTarget.attributes[aindex];
                const cgltf_accessor *accessor = attribute.data;
                const cgltf_attribute_type atype = attribute.type;
                if (atype == cgltf_attribute_type_tangent) {
                    continue;
                }
                if (
                    atype == cgltf_attribute_type_normal ||
                    atype == cgltf_attribute_type_position
                ) {
                  
                  //
                  // the texture needs to be sized according to the total number of vertices in the mesh
                  // this is identified by the highest vertex index of all primitives in the mesh
                  
                    // All position & normal attributes must have the same data type.
                    assert_invariant(
                            !previous || previous->component_type == accessor->component_type);
                    assert_invariant(!previous || previous->type == accessor->type);
                    previous = accessor;

                    // This should always be non-null, but don't crash if the glTF is malformed.
                    if (accessor->buffer_view) {
                        auto bufferData = (const uint8_t *) accessor->buffer_view->buffer->data;
                        assert_invariant(bufferData);
                        const uint8_t *data = computeBindingOffset(accessor) + bufferData;
                        const uint32_t size = computeBindingSize(accessor);
                        animatedPrimitive->targets.push_back({data, size, targetIndex, atype});
                    }
                }
            }
        }
    }
}
