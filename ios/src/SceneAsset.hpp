#pragma once

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>

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
            SceneAsset(FilamentAsset* asset, Engine* engine, NameComponentManager* ncm);
            ~SceneAsset();

            unique_ptr<vector<string>> getTargetNames(const char* meshName);
            unique_ptr<vector<string>> getAnimationNames();

            ///
            /// Update the bone/morph target animations to reflect the current frame (if applicable).
            ///
            void updateAnimations();

            ///
            /// Immediately stop the currently playing animation. NOOP if no animation is playing.
            ///
            void stopAnimation();

            ///  
            /// Play an embedded animation (i.e. an animation node embedded in the GLTF asset). If [loop] is true, the animation will repeat indefinitely.
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

            const utils::Entity* getCameraEntities();

            size_t getCameraEntityCount();


        private:
            FilamentAsset* _asset = nullptr;
            Engine* _engine = nullptr;
            NameComponentManager* _ncm;
            void updateMorphAnimation();
            void updateEmbeddedAnimation();

            Animator* _animator;
            
            // animation flags;
            bool isAnimating;
            unique_ptr<MorphAnimationStatus> _morphAnimationBuffer;
            unique_ptr<BoneAnimationStatus> _boneAnimationStatus;

    };
}