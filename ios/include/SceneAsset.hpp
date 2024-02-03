#pragma once

#include "Log.hpp"

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Texture.h>
#include <filament/TransformManager.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/ResourceLoader.h>
#include <utils/NameComponentManager.h>

extern "C" {
    #include "FlutterFilamentApi.h"
}
template class std::vector<float>;
namespace polyvox {
    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;
    using namespace std;

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;   

    enum AnimationType {
        MORPH, BONE, GLTF
    };

    struct AnimationStatus {
        time_point_t start = time_point_t::max();
        bool loop = false;
        bool reverse = false;
        float durationInSecs = 0;  
    };

    struct GltfAnimation : AnimationStatus { 
        int index = -1;        
    };

    // 
    // Use this to construct a dynamic (i.e. non-glTF embedded) morph target animation.
    //
    struct MorphAnimation : AnimationStatus {
        utils::Entity meshTarget;
        int numFrames = -1;
        float frameLengthInMs = 0;
        vector<float> frameData;
        vector<int> morphIndices;
        int lengthInFrames;
    };

    // 
    // Use this to construct a dynamic (i.e. non-glTF embedded) bone/joint animation.
    //
    struct BoneAnimation : AnimationStatus {
        size_t boneIndex;
        vector<utils::Entity> meshTargets;
        size_t skinIndex = 0;
        int lengthInFrames;
        float frameLengthInMs = 0;
        vector<math::mat4f> frameData;
    };

    struct SceneAsset {
        FilamentAsset* asset = nullptr;
        vector<math::mat4f> initialJointTransforms;
        vector<GltfAnimation> gltfAnimations;
        vector<MorphAnimation> morphAnimations;
        vector<BoneAnimation> boneAnimations;
        
        // the index of the last active glTF animation, 
        // used to cross-fade
        int fadeGltfAnimationIndex = -1;
        float fadeDuration = 0.0f;
        float fadeOutAnimationStart = 0.0f;

        // a slot to preload textures
        filament::Texture* texture = nullptr;

      SceneAsset(
            FilamentAsset* asset
        ) : asset(asset) {}
    };
}
