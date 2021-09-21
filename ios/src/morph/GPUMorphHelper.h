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

#include "FFilamentAsset.h"
#include "FFilamentInstance.h"
#include "filament/Texture.h"
#include "filament/Engine.h"
#include <math/vec4.h>

#include <tsl/robin_map.h>

#include <vector>

using namespace filament;

struct cgltf_node;
struct cgltf_mesh;
struct cgltf_primitive;

namespace gltfio {

  ///
  /// A GPUMorphHelper instance can be created per mesh (this avoids creating textures for meshes that do not require animation).
  /// For each primitive in the mesh, a texture is created to store the target positions and normals.
  /// The texture is laid out as x * 1 * z, where z is the number of morph targets and x is the number of vertices for the primitive.
  /// A MaterialInstance is created for each primitive, then applied to the entity identified by entityName.
  ///
    class GPUMorphHelper {
    public:
        using Entity = utils::Entity;

        GPUMorphHelper(FFilamentAsset *asset, const char* meshName, int primitiveIndex);

        ~GPUMorphHelper();

        void applyWeights(float const *weights, size_t count) noexcept;

    private:
        int mPrimitiveIndex;
        struct GltfTarget {
            const void *bufferObject;
            uint32_t bufferSize;
            int morphTargetIndex;
            cgltf_attribute_type type;
        };

        struct GltfPrimitive {
            filament::VertexBuffer *vertexBuffer;
            Texture* texture;
            std::vector <GltfTarget> targets; // TODO: flatten this?
            const char* materialName;
            cgltf_size numTargets = 0;
            cgltf_size numVertices = 0;
            MaterialInstance* materialInstance;
        };

        int numAttributes = 2; // position & normal

        uint32_t* indicesBuffer = nullptr;

        void addPrimitive(cgltf_mesh const *mesh);

        void createTextures();

        cgltf_mesh const* targetMesh;

        FFilamentAsset *mAsset;
        std::unique_ptr<GltfPrimitive> animatedPrimitive;
    };
}
