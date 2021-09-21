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

    GPUMorphHelper::GPUMorphHelper(FFilamentAsset *asset, const char* meshName, const char* entityName, const char* materialInstanceName) : mAsset(asset) {

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
                  for (cgltf_size pi = 0, count = mesh->primitives_count; pi < count; ++pi) {
                    addPrimitive(mesh, pi, &mMorphTable[pair.second]);
                  }
                }
            }
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

        for (auto &entry : mMorphTable) {
            for (auto prim : entry.second.primitives) {
                // for a single morph target, each vertex will be assigned 2 pixels, corresponding to a position vec3 and a normal vec3
                // these two vectors will be laid out adjacent in memory
                // the total texture "width" is the total number of these pixels
                // morph targets are then assigned to the depth channel
                auto textureWidth = prim.numVertices * 2;

                // the total size of the texture in bytes
                // equal to (numVertices * numAttributes * vectorSize (3) * sizeof(float) * numMorphTargets)
                auto textureSize = textureWidth * 3 * sizeof(float) * prim.numTargets;
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
                for (auto &target : prim.targets) {
                    if(target.type == cgltf_attribute_type_position
                    || target.type == cgltf_attribute_type_normal
                    ) {
                        memcpy(textureBuffer+offset, target.bufferObject, target.bufferSize);
                        offset += int(target.bufferSize / sizeof(float));
                    }
                }
                              
                prim.texture = Texture::Builder()
                        .width(textureWidth) //
                        .height(1)
                        .depth(prim.numTargets)
                        .sampler(Texture::Sampler::SAMPLER_2D_ARRAY)
                        .format(Texture::InternalFormat::RGB32F)
                        .levels(0x01)
                        .build(engine);

                Texture::PixelBufferDescriptor descriptor(
                        textureBuffer,
                        textureSize,
                        Texture::Format::RGB,
                        Texture::Type::FLOAT,
                        FREE_CALLBACK,
                        nullptr);
                prim.texture->setImage(engine, 0, 0,0, 0, textureWidth, 1, prim.numTargets, std::move(descriptor));
              
                for(int i = 0; i < mAsset->getMaterialInstanceCount(); i++) {
                    const char* name = materialInstances[i]->getName();
                    std::cout << name << std::endl;
                    if(strcmp(name, prim.materialName) == 0) {
                        prim.materialInstance = materialInstances[i];
                        break;
                    }
                }
              
                if(!prim.materialInstance) {
                  exit(-1);
                }

                // this won't work if material instance is shared between primitives?
                prim.materialInstance->setParameter("dimensions", filament::math::int3 { prim.numVertices * 2, numAttributes, prim.numTargets });
                prim.materialInstance->setParameter("morphTargets", prim.texture, TextureSampler());
                float weights[prim.numTargets];
                memset(weights, 0, prim.numTargets * sizeof(float));
                prim.materialInstance->setParameter("morphTargetWeights", weights, prim.numTargets);
            }
        }
    }

    void GPUMorphHelper::applyWeights(float const *weights, size_t count, int primitiveIndex) noexcept {
        auto materialInstance = mAsset->getMaterialInstances()[primitiveIndex];
        materialInstance->setParameter("morphTargetWeights", weights, count);
//        assert(count <= numTargets);
    }

    void
    GPUMorphHelper::addPrimitive(cgltf_mesh const *mesh, int primitiveIndex, TableEntry *entry) {
        auto &engine = *mAsset->mEngine;
        const cgltf_primitive &prim = mesh->primitives[primitiveIndex];
      
        const auto &gltfioPrim = mAsset->mMeshCache.at(mesh)[primitiveIndex];
        VertexBuffer *vertexBuffer = gltfioPrim.vertices;

        entry->primitives.push_back({vertexBuffer});

        auto &morphHelperPrim = entry->primitives.back();
        morphHelperPrim.materialName = prim.material->name;
        morphHelperPrim.numTargets = prim.targets_count;
        morphHelperPrim.numVertices = vertexBuffer->getVertexCount();
      cgltf_size maxIndex = 0;
        for(int i = 0; i < prim.indices->count; i++) {
          maxIndex = std::max(cgltf_accessor_read_index(prim.indices, i), maxIndex);
        }
      
      std::cout << "Max index for primitive index " << primitiveIndex << " is " << maxIndex << " and numVertices was " << morphHelperPrim.numVertices << std::endl;


        const cgltf_accessor *previous = nullptr;

        // for this primitive, iterate over every target
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
                  //
//                  if(numVertices == 0)
  //                  numVertices = accessor->count;
//assert(numVertices == accessor->count);
                  
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
                        morphHelperPrim.targets.push_back({data, size, targetIndex, atype});
                    }
                }
            }
        }
    }
}


//VertexBuffer* vBuf = VertexBuffer::Builder()
//        .vertexCount(numVertices)
//        .bufferCount(numPrimitives)
//        .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT4, 0)
//        .build(*engine);

//numIndices = maxIndex+1; */
//numIndices = prim.indices->count;

/*indicesBuffer = (uint32_t*)malloc(sizeof(unsigned int) * prim.indices->count);

//materialInstance->setParameter("vertexIndices", indicesBuffer, numIndices);

//.require(VertexAttribute::UV0)
//.require(MaterialBuilder.VertexAttribute.CUSTOM0)
//MaterialBuilder::init();
//MaterialBuilder builder = MaterialBuilder()
//        .name("DefaultMaterial")
//        .platform(MaterialBuilder::Platform::MOBILE)
//        .targetApi(MaterialBuilder::TargetApi::ALL)
//        .optimization(MaterialBuilderBase::Optimization::NONE)
//        .shading(MaterialBuilder::Shading::LIT)
//        .parameter(MaterialBuilder::UniformType::FLOAT3, "baseColor")
//        .parameter(MaterialBuilder::UniformType::INT3, "dimensions")
//        .parameter(MaterialBuilder::UniformType::FLOAT, numTargets, MaterialBuilder::ParameterPrecision::DEFAULT, "morphTargetWeights")
//        .parameter(MaterialBuilder::SamplerType::SAMPLER_2D_ARRAY, MaterialBuilder::SamplerFormat::FLOAT, MaterialBuilder::ParameterPrecision::DEFAULT, "morphTargets")
//        .vertexDomain(VertexDomain::WORLD)
//        .material(R"SHADER(void material(inout MaterialInputs material) {
//                              prepareMaterial(material);
//                              material.baseColor.rgb = materialParams.baseColor;
//                          })SHADER")
//        .materialVertex(R"SHADER(
//                    vec3 getMorphTarget(int vertexIndex, int morphTargetIndex) {
//                        // our texture is laid out as (x,y,z) where y is 1, z is the number of morph targets, and x is the number of vertices * 2 (multiplication accounts for position + normal)
//                        // UV coordinates are normalized to (-1,1), so we divide the current vertex index by the total number of vertices to find the correct coordinate for this vertex
//                        vec3 uv = vec3(
//                            (float(vertexIndex) + 0.5) / float(materialParams.dimensions.x),
//                            0.0f,
//                            //(float(morphTargetIndex) + 0.5f) / float(materialParams.dimensions.z));
//                            float(morphTargetIndex));
//                        return texture(materialParams_morphTargets, uv).xyz;
//                    }
//
//                    void materialVertex(inout MaterialVertexInputs material) {
//                        return;
//                        // for every morph target
//                        for(int morphTargetIndex = 0; morphTargetIndex < materialParams.dimensions.z; morphTargetIndex++) {
//
//                            // get the weight to apply
//                            float weight = materialParams.morphTargetWeights[morphTargetIndex];
//
//                            // get the ID of this vertex, which will be the x-offset of the position attribute in the texture sampler
//                            int vertexId = getVertexIndex();
//
//                            // get the position of the target for this vertex
//                            vec3 morphTargetPosition = getMorphTarget(vertexId, morphTargetIndex);
//                            // update the world position of this vertex
//                            material.worldPosition.xyz += (weight * morphTargetPosition);
//
//                            // increment the vertexID by half the size of the texture to get the x-offset of the normal (all positions stored in the first half, all normals stored in the second half)
//
//                            vertexId += (materialParams.dimensions.x / 2);
//
//                            // get the normal of this target for this vertex
//                            vec3 morphTargetNormal = getMorphTarget(vertexId, morphTargetIndex);
//                            material.worldNormal += (weight * morphTargetNormal);
//                        }
//                        mat4 transform = getWorldFromModelMatrix();
//                        material.worldPosition = mulMat4x4Float3(transform, material.worldPosition.xyz);
//                    })SHADER");
//
//Package pkg = builder.build(mAsset->mEngine->getJobSystem());
//Material* material = Material::Builder().package(pkg.getData(), pkg.getSize())
//        .build(*mAsset->mEngine);

//size_t normal_size = sizeof(short4);
//assert(textureWidth * (position_size + normal_size) == textureSize);
//assert(textureWidth * position_size == textureSize);
/*__android_log_print(ANDROID_LOG_INFO, "MyTag", "Expected size  %d width at level 0 %d height", Texture::PixelBufferDescriptor::computeDataSize(Texture::Format::RGB,
                                                                                                                     Texture::Type::FLOAT, 24, 1, 4), texture->getWidth(0),texture->getHeight(0)); */

/*        Texture::PixelBufferDescriptor descriptor(
                textureBuffer,
                textureSize,
                Texture::Format::RGB,
                Texture::Type::FLOAT,
                4, 0,0, 24,
                FREE_CALLBACK,
                nullptr); */

/*for(int i = 0; i < int(textureSize / sizeof(float)); i++) {
    __android_log_print(ANDROID_LOG_INFO, "MyTag", "offset %d %f", i, *(textureBuffer+i));
//}*/
//std::cout << "Checking for " << materialInstanceName << std::endl;
//if(materialInstanceName) {
//  for(int i = 0; i < asset->getMaterialInstanceCount(); i++) {
//      const char* name = instances[i]->getName();
//      std::cout << name << std::endl;
//      if(strcmp(name, materialInstanceName) == 0) {
//          materialInstance = instances[i];
//          break;
//      }
//  }
//} else {
//  materialInstance = instances[0];
//}
//
//if(!materialInstance) {
//    exit(-1);
//}

//              std::cout << std::endl;
              /*        for (int i = 0; i < 4; i++) {
                          morphHelperPrim.positions[i] = gltfioPrim.morphPositions[i];
                          morphHelperPrim.tangents[i] = gltfioPrim.morphTangents[i];
                      } */

//        applyTextures(materialInstance);
        
/*        const Entity* entities = mAsset->getEntities();
        for(int i=0; i < mAsset->getEntityCount();i++) {
          std::cout << mAsset->getName(entities[i]);
        } */

//        Entity entity = mAsset->getFirstEntityByName(entityName);
//        RenderableManager::Instance rInst = mAsset->mEngine->getRenderableManager().getInstance(entity);
//        for(int i = 0; i<num_primitives;i++) {
//          mAsset->mEngine->getRenderableManager().setMaterialInstanceAt(rInst, i, materialInstance);
//        }
