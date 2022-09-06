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

#include "SceneResources.hpp"

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

            unique_ptr<vector<string>> getTargetNames(const char* meshName);
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
            void playAnimation(int index, bool loop);

            ///
            /// Manually set the weights for all morph targets in the assets to the provided values.
            /// See [animateWeights] if you want to automatically
            ///
            void applyWeights(float* weights, int count);

            ///
            /// Update the asset's morph target weights every "frame" (which is an arbitrary length of time, i.e. this is not the same as a frame at the framerate of the underlying rendering framework).
            /// Accordingly:
            ///       length(data) = numWeights * numFrames
            ///       total_animation_duration_in_ms = number_of_frames * frameLengthInMs
            ///
            void animateWeights(float* data, int numWeights, int numFrames, float frameLengthInMs);

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

            void updateMorphAnimation();
            void updateEmbeddedAnimations();


            Animator* _animator;
            
            // animation flags;
            unique_ptr<MorphAnimationStatus> _morphAnimationBuffer;
            vector<EmbeddedAnimationStatus> _embeddedAnimationStatus;

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