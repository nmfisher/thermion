// /*
//  * Copyright (C) 2021 The Android Open Source Project
//  *
//  * Licensed under the Apache License, Version 2.0 (the "License");
//  * you may not use this file except in compliance with the License.
//  * You may obtain a copy of the License at
//  *
//  *      http://www.apache.org/licenses/LICENSE-2.0
//  *
//  * Unless required by applicable law or agreed to in writing, software
//  * distributed under the License is distributed on an "AS IS" BASIS,
//  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  * See the License for the specific language governing permissions and
//  * limitations under the License.
//  */

// #include "CPUMorpher.h"

// #include <filament/BufferObject.h>
// #include <filament/RenderableManager.h>
// #include <filament/VertexBuffer.h>
// #include <utils/Log.h>

// #include "GltfHelpers.h"

// using namespace filament;
// using namespace filament::math;
// using namespace utils;
// using namespace gltfio;

// namespace agltfio {

// static const auto FREE_CALLBACK = [](void* mem, size_t, void*) { free(mem); };

// CPUMorpher::CPUMorpher(FFilamentAsset* asset, FFilamentInstance* instance) : mAsset(asset) {
//     NodeMap& sourceNodes = asset->isInstanced() ? asset->mInstances[0]->nodeMap : asset->mNodeMap;

//     int i = 0;
//     for (auto pair : sourceNodes) {
//         cgltf_node const* node = pair.first;
//         cgltf_mesh const* mesh = node->mesh;
//         if (mesh) {
//             cgltf_primitive const* prims = mesh->primitives;
//             for (cgltf_size pi = 0, count = mesh->primitives_count; pi < count; ++pi) {
//                 if (mesh->primitives[pi].targets_count > 0) {
//                     addPrimitive(mesh, pi, &mMorphTable[pair.second]);
//                 }
//             }
//         }
//     }
// }

// CPUMorpher::~CPUMorpher() {
//     auto engine = mAsset->mEngine;
//     for (auto& entry : mMorphTable) {
//         for (auto& prim : entry.second.primitives) {
//             if (prim.morphBuffer1) engine->destroy(prim.morphBuffer1);
//             if (prim.morphBuffer2) engine->destroy(prim.morphBuffer2);
//         }
//     }
// }

// void CPUMorpher::applyWeights(Entity entity, float const* weights, size_t count) noexcept {
//     auto& engine = *mAsset->mEngine;
//     auto renderableManager = &engine.getRenderableManager();
//     auto renderable = renderableManager->getInstance(entity);

//     for (auto& prim : mMorphTable[entity].primitives) {
//         if (prim.targets.size() < count) {
//             continue;
//         }

//         size_t size = prim.floatsCount * sizeof(float);
//         float* data = (float*) malloc(size);
//         memset(data, 0, size);

//         for (size_t index = 0; index < count; index ++) {
//             const float w = weights[index];
//             if (w < 0.0001f) continue;

//             const GltfTarget& target = prim.targets[index];
//             cgltf_size dim = cgltf_num_components(target.type); 

//             for (size_t i = 0; i < target.indices.size(); ++i) {
//                 uint16_t index = target.indices[i];
//                 for (size_t j = 0; j < dim; ++j) {
//                     data[index * dim + j] += w * target.values[i * dim + j];
//                 }
//             }
//         }
        
//         VertexBuffer* vb = prim.vertexBuffer;
//         if (!prim.morphBuffer1) {
//             prim.morphBuffer1 = BufferObject::Builder().size(size).build(engine);
//         }
//         if (!prim.morphBuffer2 && count >= 2) {
//             // This is for dealing with a bug in filament shaders where empty normals are not
//             // handled correctly.
//             //
//             // filament shaders deal with tangent frame quaternions instead of normal vectors.
//             // But in case of missing inputs, we get a invalid quaternion (0, 0, 0, 0) instead of
//             // a identity quaterion. This leads to the normals being morphed even no inputs are
//             // given.
//             // 
//             // To fix this, we put a empty morph target at slot 2 and give it a weight of -1.
//             // This won't affect the vertex positions but will cancel out the normal values.
//             //
//             // Note that for this to work, at least two morph targets are required.
//             float* data2 = (float*) malloc(size);
//             memset(data2, 0, size);
//             VertexBuffer::BufferDescriptor bd2(data2, size, FREE_CALLBACK);
//             prim.morphBuffer2 = BufferObject::Builder().size(size).build(engine);
//             prim.morphBuffer2->setBuffer(engine, std::move(bd2));
//             vb->setBufferObjectAt(engine, prim.baseSlot+1, prim.morphBuffer2);
//         }
//         VertexBuffer::BufferDescriptor bd(data, size, FREE_CALLBACK);
//         prim.morphBuffer1->setBuffer(engine, std::move(bd));
//         vb->setBufferObjectAt(engine, prim.baseSlot, prim.morphBuffer1);
//     }
//     renderableManager->setMorphWeights(renderable, {1, -1, 0, 0});
// }

// // // This method copies various morphing-related data from the FilamentAsset MeshCache primitive
// // // (which lives in transient memory) into the MorphHelper primitive (which will stay resident).
// // void MorphHelper::addPrimitive(cgltf_mesh const* mesh, int primitiveIndex, TableEntry* entry) {
// //     auto& engine = *mAsset->mEngine;
// //     const cgltf_primitive& prim = mesh->primitives[primitiveIndex];
// //     const auto& gltfioPrim = mAsset->mMeshCache.at(mesh)[primitiveIndex];
// //     VertexBuffer* vertexBuffer = gltfioPrim.vertices;

// //     entry->primitives.push_back({ vertexBuffer });
// //     auto& morphHelperPrim = entry->primitives.back();

// //     for (int i = 0; i < 4; i++) {
// //         morphHelperPrim.positions[i] = gltfioPrim.morphPositions[i];
// //         morphHelperPrim.tangents[i] = gltfioPrim.morphTangents[i];
// //     }

// //     const cgltf_accessor* previous = nullptr;
// //     for (int targetIndex = 0; targetIndex < prim.targets_count; targetIndex++) {
// //         const cgltf_morph_target& morphTarget = prim.targets[targetIndex];
// //         for (cgltf_size aindex = 0; aindex < morphTarget.attributes_count; aindex++) {
// //             const cgltf_attribute& attribute = morphTarget.attributes[aindex];
// //             const cgltf_accessor* accessor = attribute.data;
// //             const cgltf_attribute_type atype = attribute.type;
// //             if (atype == cgltf_attribute_type_tangent) {
// //                 continue;
// //             }
// //             if (atype == cgltf_attribute_type_normal) {

// //                 // TODO: use JobSystem for this, like what we do for non-morph tangents.
// //                 TangentsJob job;
// //                 TangentsJob::Params params = { .in = { &prim, targetIndex } };
// //                 TangentsJob::run(&params);

// //                 if (params.out.results) {
// //                     const size_t size = params.out.vertexCount * sizeof(short4);
// //                     BufferObject* bufferObject = BufferObject::Builder().size(size).build(engine);
// //                     VertexBuffer::BufferDescriptor bd(params.out.results, size, FREE_CALLBACK);
// //                     bufferObject->setBuffer(engine, std::move(bd));
// //                     params.out.results = nullptr;
// //                     morphHelperPrim.targets.push_back({bufferObject, targetIndex, atype});
// //                 }
// //                 continue;
// //             }
// //             if (atype == cgltf_attribute_type_position) {
// //                 // All position attributes must have the same data type.
// //                 assert_invariant(!previous || previous->component_type == accessor->component_type);
// //                 assert_invariant(!previous || previous->type == accessor->type);
// //                 previous = accessor;

// //                 // This should always be non-null, but don't crash if the glTF is malformed.
// //                 if (accessor->buffer_view) {
// //                     auto bufferData = (const uint8_t*) accessor->buffer_view->buffer->data;
// //                     assert_invariant(bufferData);
// //                     const uint8_t* data = computeBindingOffset(accessor) + bufferData;
// //                     const uint32_t size = computeBindingSize(accessor);

// //                     // This creates a copy because we don't know when the user will free the cgltf
// //                     // source data. For non-morphed vertex buffers, we use a sharing mechanism to
// //                     // prevent copies, but here we just want to keep it as simple as possible.
// //                     uint8_t* clone = (uint8_t*) malloc(size);
// //                     memcpy(clone, data, size);

// //                     BufferObject* bufferObject = BufferObject::Builder().size(size).build(engine);
// //                     VertexBuffer::BufferDescriptor bd(clone, size, FREE_CALLBACK);
// //                     bufferObject->setBuffer(engine, std::move(bd));
// //                     morphHelperPrim.targets.push_back({bufferObject, targetIndex, atype});
// //                 }
// //             }
// //         }
// //     }
// // }

// void CPUMorpher::addPrimitive(cgltf_mesh const* mesh, int primitiveIndex, TableEntry* entry) {

//     auto& engine = *mAsset->mEngine;
//     const cgltf_primitive& cgltf_prim = mesh->primitives[primitiveIndex];

//     int posIndex = findPositionAttribute(cgltf_prim);
//     if (posIndex < 0) return;

//     VertexBuffer* vertexBuffer = mAsset->mMeshCache.at(mesh)[primitiveIndex].vertices;
//     int slot = determineBaseSlot(cgltf_prim);
//     entry->primitives.push_back({ vertexBuffer, slot });

//     auto& primitive = entry->primitives.back();

//     cgltf_attribute& positionAttribute = cgltf_prim.attributes[posIndex];
//     size_t dim = cgltf_num_components(positionAttribute.data->type);
//     primitive.floatsCount = positionAttribute.data->count * dim;

//     std::vector<GltfTarget>& targets = primitive.targets;

//     for (int targetIndex = 0; targetIndex < cgltf_prim.targets_count; targetIndex++) {
//         const cgltf_morph_target& morphTarget = cgltf_prim.targets[targetIndex];
//         for (cgltf_size aindex = 0; aindex < morphTarget.attributes_count; aindex++) {
//             const cgltf_attribute& attribute = morphTarget.attributes[aindex];
//             const cgltf_accessor* accessor = attribute.data;
//             const cgltf_attribute_type atype = attribute.type;

//             // only works for morphing of positions for now
//             if (atype == cgltf_attribute_type_position || atype == cgltf_attribute_type_normal) {
//                 targets.push_back({targetIndex, atype, accessor->type});
//                 cgltf_size floats_per_element = cgltf_num_components(accessor->type);

//                 targets.back().indices.resize(accessor->count);
//                 targets.back().values.resize(accessor->count * floats_per_element);
//                 cgltf_size unpacked = cgltf_accessor_unpack_floats(accessor, targets.back().values.data(), accessor->count * floats_per_element);
//                 for(int i = 0; i < accessor->count; i++) {
//                     targets.back().indices[i] = i;
//                 /*    for(int j = 0; j < floats_per_element; j++) {
//                         size_t offset = (i * floats_per_element) + j;
//                         cgltf_element_read_float
//                         float cgv = cgltf_accessor_unpack_floats(accessor->buffer_view + offset, accessor->component_type, accessor->normalized);
//                         if(cgv > 0) {
//                             size_t foo = 1;
//                             targets.back().values[offset] = cgv;
//                         }
//                         targets.back().values[offset] = cgv;
//                     } */
//                 }
//                     //cgltf_size unpacked = cgltf_accessor_unpack_floats(accessor, targets.back().values.data(), floats_per_element);
//             }
//         }
//     }
// }

// // trying to find the slot for the vertex position
// int CPUMorpher::determineBaseSlot(const cgltf_primitive& prim) const {
//     int slot = 0;
//     bool hasNormals = false;
//     for (cgltf_size aindex = 0; aindex < prim.attributes_count; aindex++) {
//         const cgltf_attribute& attribute = prim.attributes[aindex];
//         const int index = attribute.index;
//         const cgltf_attribute_type atype = attribute.type;
//         const cgltf_accessor* accessor = attribute.data;
//         if (atype == cgltf_attribute_type_tangent) {
//             continue;
//         }
//         if (atype == cgltf_attribute_type_normal) {
//             slot++;
//             hasNormals = true;
//             continue;
//         }

//         // Filament supports two set of texcoords. But whether or not UV1 is actually used also
//         // depends on the material.
//         // Note this is a very specific fix that might not work in all cases.
//         if (atype == cgltf_attribute_type_texcoord && index > 0) {
//             bool hasUV1 = false;
//             cgltf_material* mat = prim.material;
//             if (mat->has_pbr_metallic_roughness) {
//                 if (mat->pbr_metallic_roughness.base_color_texture.texcoord != 0) {
//                     hasUV1 = true;
//                 }
//                 if (mat->pbr_metallic_roughness.metallic_roughness_texture.texcoord != 0) {
//                     hasUV1 = true;
//                 }
//             }
//             if (mat->normal_texture.texcoord != 0) hasUV1 = true;
//             if (mat->emissive_texture.texcoord != 0) hasUV1 = true;
//             if (mat->occlusion_texture.texcoord != 0) hasUV1 = true;

//             if (hasUV1) slot++;
//             continue;
//         }
        
//         slot++;
//     }

//     // If the model has lighting but not normals, then a slot is used for generated flat normals.
//     if (prim.material && !prim.material->unlit && !hasNormals) {
//         slot++;
//     }

//     return slot;
// };

// int CPUMorpher::findPositionAttribute(const cgltf_primitive& prim) const {
//     for (cgltf_size aindex = 0; aindex < prim.attributes_count; aindex++) {
//         if (prim.attributes[aindex].type == cgltf_attribute_type_position) {
//             return aindex;
//         }
//     }

//     return -1;
// };

// } // namespace gltfio
