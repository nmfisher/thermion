#pragma once

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Texture.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>

#include <utils/NameComponentManager.h>

#include "ResourceManagement.hpp"
#include "SceneAssetAnimation.hpp"
#include "PolyvoxFilamentApi.h"

namespace polyvox {
    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;
    using namespace std;

    class SceneAsset {
        friend class SceneAssetLoader;
        public:
            SceneAsset(FilamentAsset* asset, Engine* engine, NameComponentManager* ncm, LoadResource loadResource, FreeResource freeResource);
            ~SceneAsset();

            unique_ptr<vector<string>> getMorphTargetNames(const char* meshName);
            unique_ptr<vector<string>> getAnimationNames();

            ///
            ///
            ///
            void loadTexture(const char* resourcePath, int renderableIndex);
            void setTexture();

            ///
            /// Update the bone/morph target animations to reflect the current frame (if applicable).
            ///
            void updateAnimations();

            ///
            /// Immediately stop the animation at the specified index. Noop if no animation is playing.
            ///
            void stopAnimation(int index);

            ///  
            /// Play the embedded animation (i.e. animation node embedded in the GLTF asset) under the specified index. If [loop] is true, the animation will repeat indefinitely.
            ///
            void playAnimation(int index, bool loop, bool reverse);

            ///
            /// Manually set the weights for all morph targets in the assets to the provided values.
            /// See [setAnimation] if you want to do the same across a number of frames (and extended to bone transforms).
            ///
            void setMorphTargetWeights(float* weights, int count);

            ///
            /// Animates the asset's morph targets/bone transforms according to the frame weights/transforms specified in [morphData]/[boneData].
            ///  The duration of each "frame" is specified by [frameLengthInMs] (i.e. this is not the framerate of the renderer).
            /// [morphData] is a contiguous chunk of floats whose length will be (numMorphWeights * numFrames).
            /// [boneData] is a contiguous chunk of floats whose length will be (numBones * 7 * numFrames) (where 7 is 3 floats for translation, 4 for quat rotation).
            /// [morphData] and [boneData] will both be copied, so remember to free these after calling this function.
            ///
            void setAnimation(
                float* morphData, 
                int numMorphWeights, 
                BoneAnimation* targets,
                int numBoneAnimations,
                int numFrames, 
                float frameLengthInMs
            );

            void fillEntitiesByName(const char** name, int count, vector<Entity>& out);
            size_t getBoneIndex(const char* name);
            
            Entity getNode(const char* name);

            void transformToUnitCube();

            void setScale(float scale);

            void setPosition(float x, float y, float z);
            
            void setRotation(float rads, float x, float y, float z);         

            const utils::Entity* getCameraEntities();

            size_t getCameraEntityCount();

            const Entity* getLightEntities() const noexcept;

            size_t getLightEntityCount() const noexcept;


        private:

            FilamentAsset* _asset = nullptr;
            Engine* _engine = nullptr;
            NameComponentManager* _ncm;

            void setBoneTransform(
                uint8_t skinIndex,
                const vector<uint8_t>& boneIndices,
                const vector<Entity>& targets, 
                const vector<float> data,
                int frameNumber
            );

            void updateRuntimeAnimation();

            void updateEmbeddedAnimations();

            Animator* _animator;
            
            // animation flags;
            unique_ptr<RuntimeAnimation> _runtimeAnimationBuffer;
            vector<GLTFAnimation> _embeddedAnimationStatus;

            LoadResource _loadResource;
            FreeResource _freeResource;

            // a slot to preload textures
            filament::Texture* _texture = nullptr;

            // initialized to identity
            math::mat4f _position;
            
            // initialized to identity
            math::mat4f _rotation;
            
            float _scale = 1;

            void updateTransform();

    };
}
