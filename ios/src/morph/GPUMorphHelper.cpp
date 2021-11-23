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

#include "upcast.h"

#include <backend/Handle.h>

#include <filament/Texture.h>

#include <utils/compiler.h>


namespace gltfio {

    static constexpr uint8_t kUnused = 0xff;

    uint32_t computeBindingSize(const cgltf_accessor *accessor);

    uint32_t computeBindingOffset(const cgltf_accessor *accessor);

    static const auto FREE_CALLBACK = [](void *mem, size_t s, void *) {
        free(mem);
    };

    GPUMorphHelper::GPUMorphHelper(FFilamentAsset *asset, const char* meshName, int* primitiveIndices, int numPrimitives) : mAsset(asset) {

        NodeMap &sourceNodes = asset->isInstanced() ? asset->mInstances[0]->nodeMap
                                                  : asset->mNodeMap;

        for (auto pair : sourceNodes) {
            cgltf_node const *node = pair.first;
            cgltf_mesh const *mesh = node->mesh;

            if (mesh) {
                std::cout << "Mesh " << mesh->name << " with " << mesh->weights_count << " weights and " << mesh->primitives_count << " primitives." <<  std::endl;
                if(strcmp(meshName, mesh->name) == 0) {
                  targetMesh = mesh;
                  for(int i = 0; i < numPrimitives; i++) {
                    int primitiveIndex = primitiveIndices[i];
                //for(int primitiveIndex = 0; primitiveIndex < targetMesh->primitives_count; primitiveIndex++) {
                    std::cout << "Adding primitive at index " << primitiveIndex << " to morpher "  <<  std::endl;
                    addPrimitive(mesh, primitiveIndex);
                  }
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
           
        applyWeights(targetMesh->weights, targetMesh->weights_count);
          
    }

    GPUMorphHelper::~GPUMorphHelper() {

    }

    ///
    /// Creates the texture that will store the morphable attributes. The texture will be sized according to the total number of vertices in the mesh, meaning all primitives share the same texture.
    ///
    void GPUMorphHelper::createTextures() {
        auto materialInstances = mAsset->getMaterialInstances();
        auto &engine = *(mAsset->mEngine);
      
        for(auto& prim : animatablePrimitives) {
      
          // for a single morph target, each vertex will be assigned 2 pixels, corresponding to a position vec3 and a normal vec3
          // these two vectors will be laid out adjacent in memory
          // the total texture "width" is the total number of these pixels
          // morph targets are then assigned to the depth channel
          auto textureWidth = prim->numVertices * numAttributes;

          // the total size of the texture in bytes
          // equal to (numVertices * numAttributes * vectorSize (3) * sizeof(float) * numMorphTargets)
          auto textureSize = textureWidth * 3 * sizeof(float) * prim->numTargets;
          auto textureBuffer = (float *const) malloc(textureSize);
        
          if(!textureBuffer) {
            std::cout << "Error allocating texture buffer" << std::endl;
            exit(-1);
          }
          
          memset(textureBuffer, 0, textureSize);
        
          uint32_t offset = 0;
        
          // assume the primitive morph target source buffer is laid out like:
          // |target0_v0_pos * 3|target0_v1_pos * 3|...|target0_v0_norm * 3|target0_v1_norm * 3|...|target1_v0_pos * 3|target1_v1_pos * 3|...|target1_v0_norm * 3|target1_v1_norm * 3|...
          // where:
          // - target0/target1/etc is the first/second/etc morph target
          // - v0/v1/etc is the first/second/etc vertex
          // - pos/norm are each 3-float vectors
          for (auto &target : prim->targets) {
              if(target.type == cgltf_attribute_type_position
               || (numAttributes > 1 && target.type == cgltf_attribute_type_normal)
              ) {
                float attr = (float)textureBuffer[offset];
                  memcpy(textureBuffer+offset, target.bufferObject, target.bufferSize);
                  offset += int(target.bufferSize / sizeof(float));
              }
          }
        
          Texture* texture = Texture::Builder()
                .width(textureWidth) //
                .height(1)
                .depth(prim->numTargets)
                .sampler(Texture::Sampler::SAMPLER_2D_ARRAY)
                .format(backend::TextureFormat::RGB32F)
                .levels(0x01)
                .build(engine);
          
          prim->texture = texture; //std::unique_ptr<Texture>(texture);

          Texture::PixelBufferDescriptor descriptor(
                  textureBuffer,
                  textureSize,
                  backend::PixelDataFormat::RGB,
                  backend::PixelDataType::FLOAT,
                  FREE_CALLBACK,
                  nullptr);
          prim->texture->setImage(engine, 0, 0,0, 0, textureWidth, 1, prim->numTargets, std::move(descriptor));
        
          for(int i = 0; i < mAsset->getMaterialInstanceCount(); i++) {
              const char* name = materialInstances[i]->getName();
              if(strcmp(name, prim->materialName) == 0) {
                  const char* m = materialInstances[i]->getMaterial()->getName();
                  std::cout << "Found material instance for material " << m << " and primitive under name : " << name << std::endl;
                  prim->materialInstance = materialInstances[i]; //std::unique_ptr<MaterialInstance>(materialInstances[i]);
                  break;
              }
          }
        
          if(!prim->materialInstance) {
            exit(-1);
          }
          
          float dimensions[] = { float(prim->numVertices), float(numAttributes), float(prim->numTargets) };
        
          prim->materialInstance->setParameter("dimensions", dimensions, 3);
  //        TextureSampler sampler(filament::backend::SamplerMagFilter::NEAREST, filament::TextureSampler::WrapMode::REPEAT);

          prim->materialInstance->setParameter("morphTargets", prim->texture, TextureSampler());
          float weights[prim->numTargets];
          memset(weights, 0, prim->numTargets * sizeof(float));
          prim->materialInstance->setParameter("morphTargetWeights", weights, prim->numTargets);
        }
    }

    void GPUMorphHelper::applyWeights(float const *weights, size_t count) noexcept {
      for(auto& prim : animatablePrimitives) {
        prim->materialInstance->setParameter("morphTargetWeights", weights, count);
      }
    }

    void
    GPUMorphHelper::addPrimitive(cgltf_mesh const *mesh, int primitiveIndex) {
        auto &engine = *mAsset->mEngine;
        const cgltf_primitive &prim = mesh->primitives[primitiveIndex];
      
        const auto &gltfioPrim = mAsset->mMeshCache.at(mesh)[primitiveIndex];
        VertexBuffer *vertexBuffer = gltfioPrim.vertices;
        std::unique_ptr<GltfPrimitive> animatedPrimitive = std::make_unique<GltfPrimitive>(GltfPrimitive{vertexBuffer});

        animatedPrimitive->materialName = prim.material->name;
        animatedPrimitive->numTargets = prim.targets_count;
        animatedPrimitive->numVertices = vertexBuffer->getVertexCount();
      
        std::cout << "Found " << animatedPrimitive->numVertices << " vertices in primitive" << std::endl;
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
                if (atype == cgltf_attribute_type_position || numAttributes > 1 && atype == cgltf_attribute_type_normal) {
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
        animatablePrimitives.push_back(std::move(animatedPrimitive));
    }
}


//           assert(
//             FTexture::validatePixelFormatAndType(
//               backend::TextureFormat::RGB32F,
//               backend::PixelDataFormat::RGB,
//               backend::PixelDataType::FLOAT));

//               namespace filament {

// class FEngine;
// class FStream;

// class FTexture : public Texture {
// public:
//     FTexture(FEngine& engine, const Builder& builder);

//     // frees driver resources, object becomes invalid
//     void terminate(FEngine& engine);

//     backend::Handle<backend::HwTexture> getHwHandle() const noexcept { return mHandle; }

//     size_t getWidth(size_t level = 0) const noexcept;
//     size_t getHeight(size_t level = 0) const noexcept;
//     size_t getDepth(size_t level = 0) const noexcept;
//     size_t getLevelCount() const noexcept { return mLevelCount; }
//     size_t getMaxLevelCount() const noexcept { return FTexture::maxLevelCount(mWidth, mHeight); }
//     Sampler getTarget() const noexcept { return mTarget; }
//     InternalFormat getFormat() const noexcept { return mFormat; }
//     Usage getUsage() const noexcept { return mUsage; }

//     void setImage(FEngine& engine, size_t level,
//             uint32_t xoffset, uint32_t yoffset, uint32_t width, uint32_t height,
//             PixelBufferDescriptor&& buffer) const;

//     void setImage(FEngine& engine, size_t level,
//             uint32_t xoffset, uint32_t yoffset, uint32_t zoffset,
//             uint32_t width, uint32_t height, uint32_t depth,
//             PixelBufferDescriptor&& buffer) const;

//     void setImage(FEngine& engine, size_t level,
//             PixelBufferDescriptor&& buffer, const FaceOffsets& faceOffsets) const;

//     void generatePrefilterMipmap(FEngine& engine,
//             PixelBufferDescriptor&& buffer, const FaceOffsets& faceOffsets,
//             PrefilterOptions const* options);

//     void setExternalImage(FEngine& engine, void* image) noexcept;
//     void setExternalImage(FEngine& engine, void* image, size_t plane) noexcept;
//     void setExternalStream(FEngine& engine, FStream* stream) noexcept;

//     void generateMipmaps(FEngine& engine) const noexcept;

//     void setSampleCount(size_t sampleCount) noexcept { mSampleCount = uint8_t(sampleCount); }
//     size_t getSampleCount() const noexcept { return mSampleCount; }
//     bool isMultisample() const noexcept { return mSampleCount > 1; }
//     bool isCompressed() const noexcept { return backend::isCompressedFormat(mFormat); }

//     bool isCubemap() const noexcept { return mTarget == Sampler::SAMPLER_CUBEMAP; }

//     FStream const* getStream() const noexcept { return mStream; }

//     /*
//      * Utilities
//      */

//     // synchronous call to the backend. returns whether a backend supports a particular format.
//     static bool isTextureFormatSupported(FEngine& engine, InternalFormat format) noexcept;

//     // synchronous call to the backend. returns whether a backend supports texture swizzling.
//     static bool isTextureSwizzleSupported(FEngine& engine) noexcept;

//     // storage needed on the CPU side for texture data uploads
//     static size_t computeTextureDataSize(Texture::Format format, Texture::Type type,
//             size_t stride, size_t height, size_t alignment) noexcept;

//     // Size a of a pixel in bytes for the given format
//     static size_t getFormatSize(InternalFormat format) noexcept;

//     // Returns the with or height for a given mipmap level from the base value.
//     static inline size_t valueForLevel(uint8_t level, size_t baseLevelValue) {
//         return std::max(size_t(1), baseLevelValue >> level);
//     }

//     // Returns the max number of levels for a texture of given max dimensions
//     static inline uint8_t maxLevelCount(uint32_t maxDimension) noexcept {
//         return std::max(1, std::ilogbf(maxDimension) + 1);
//     }

//     // Returns the max number of levels for a texture of given dimensions
//     static inline uint8_t maxLevelCount(uint32_t width, uint32_t height) noexcept {
//         return std::max(1, std::ilogbf(std::max(width, height)) + 1);
//     }

//     static bool validatePixelFormatAndType(backend::TextureFormat internalFormat,
//             backend::PixelDataFormat format, backend::PixelDataType type) noexcept;

// private:
//     friend class Texture;
//     FStream* mStream = nullptr;
//     backend::Handle<backend::HwTexture> mHandle;
//     uint32_t mWidth = 1;
//     uint32_t mHeight = 1;
//     uint32_t mDepth = 1;
//     InternalFormat mFormat = InternalFormat::RGBA8;
//     Sampler mTarget = Sampler::SAMPLER_2D;
//     uint8_t mLevelCount = 1;
//     uint8_t mSampleCount = 1;
//     Usage mUsage = Usage::DEFAULT;
// };


// } // namespace filament
