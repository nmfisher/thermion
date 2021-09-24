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

// #ifndef GLTFIO_CPUMORPHER_H
// #define GLTFIO_CPUMORPHER_H

// #include "Morpher.h"

// #include "FFilamentAsset.h"
// #include "FFilamentInstance.h"

// #include <math/vec4.h>

// #include <tsl/robin_map.h>

// #include <vector>

// struct cgltf_node;
// struct cgltf_mesh;
// struct cgltf_primitive;
// struct cgltf_attribute;

// using namespace gltfio;


// namespace agltfio {

// /**
//  * Helper for supporting more than 4 active morph targets.
//  *
//  * All morph values are calculated on CPU and collected into a single target, which will be
//  * uploaded with weight of 1. This is effectively doing the morphing on CPU.
//  * 
//  * Obviously this is slower than the stock morpher as it needs to upload buffer every frame.
//  * So beware of the performance penalty.
//  */
// class CPUMorpher : public Morpher {
// public:
//     using Entity = utils::Entity;
//     CPUMorpher(FFilamentAsset* asset, FFilamentInstance* instance);
//     ~CPUMorpher();

//     void applyWeights(Entity targetEntity, float const* weights, size_t count) noexcept;

// private:
//     struct GltfTarget {
//         int morphTargetIndex;
//         cgltf_attribute_type attribute_type;
//         cgltf_type type;
//         std::vector<uint16_t> indices;
//         std::vector<float> values;
//     };

//     struct GltfPrimitive {
//         filament::VertexBuffer* vertexBuffer;
//         int baseSlot;
//         size_t floatsCount;
//         filament::BufferObject* morphBuffer1 = nullptr;
//         filament::BufferObject* morphBuffer2 = nullptr;
//         std::vector<GltfTarget> targets;
//     };

//     struct TableEntry {
//         std::vector<GltfPrimitive> primitives;
//     };

//     void addPrimitive(cgltf_mesh const* mesh, int primitiveIndex, TableEntry* entry);
//     int determineBaseSlot(const cgltf_primitive& prim) const;
//     int findPositionAttribute(const cgltf_primitive& prim) const;

//     std::vector<float> mPartiallySortedWeights;
//     tsl::robin_map<Entity, TableEntry> mMorphTable;
//     const FFilamentAsset* mAsset;
// };

// } // namespace gltfio

// #endif // GLTFIO_CPUMORPHER_H
