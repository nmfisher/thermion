#pragma once

#include "Log.hpp"

#include <filament/Engine.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Texture.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include <gltfio/Animator.h>
#include <gltfio/AssetLoader.h>
#include <gltfio/ResourceLoader.h>
#include <utils/NameComponentManager.h>

extern "C" {
    #include "PolyvoxFilamentApi.h"
}

namespace polyvox {
    using namespace filament;
    using namespace filament::gltfio;
    using namespace utils;
    using namespace std;

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;   

    struct AnimationStatus {
        time_point_t mStart = time_point_t::max();
        bool mLoop = false;
        bool mReverse = false;
        float mDuration = 0;
        bool mAnimating = false;

        // AnimationStatus() {
        //     Log("default constr");
        // }

        // AnimationStatus(AnimationStatus& a) {
        //     mStart = a.mStart;
        //     mLoop = a.mLoop;
        //     mReverse = a.mReverse;
        //     mDuration = a.mDuration;
        //     mFrameNumber = a.mFrameNumber;
        // }

        // AnimationStatus& operator=(AnimationStatus a) {
        //     mStart = a.mStart;
        //     mLoop = a.mLoop;
        //     mReverse = a.mReverse;
        //     mDuration = a.mDuration;
        //     mFrameNumber = a.mFrameNumber;
        //     return *this;
        // }

        // AnimationStatus(AnimationStatus&& a) {
        //     mStart = a.mStart;
        //     mLoop = a.mLoop;
        //     mReverse = a.mReverse;
        //     mDuration = a.mDuration;
        //     mFrameNumber = a.mFrameNumber;
        // }
    };

    // 
    // Use this to manually construct a buffer of frame data for morph animations.
    //
    struct MorphAnimationBuffer {
        utils::Entity mMeshTarget;
        int mNumFrames = -1;
        float mFrameLengthInMs = 0;
        vector<float> mFrameData;
        int mNumMorphWeights = 0;
    };

    ///
    /// Frame data for the bones/meshes specified by [mBoneIndices] and [mMeshTargets].
    /// This is mainly used as a wrapper for animation data being transferred from the Dart to the native side.
    ///
    struct BoneAnimationData {
        size_t skinIndex = 0;
        uint8_t mBoneIndex;
        utils::Entity mMeshTarget;
        vector<float> mFrameData;
    };

    // 
    // Use this to manually construct a buffer of frame data for bone animations.
    //
    struct BoneAnimationBuffer {
        int mNumFrames = -1;
        float mFrameLengthInMs = 0;
        vector<BoneAnimationData> mAnimations;
    };

    struct SceneAsset {
        bool mAnimating = false;
        FilamentAsset* mAsset = nullptr;
        Animator* mAnimator = nullptr;

        // fixed-sized vector containing the status of the morph, bone and GLTF animations.
        // entries 0 and 1 are the morph/bone animations.
        // subsequent entries are the GLTF animations.
        vector<AnimationStatus> mAnimations;

        MorphAnimationBuffer mMorphAnimationBuffer;
        BoneAnimationBuffer mBoneAnimationBuffer;

        // a slot to preload textures
        filament::Texture* mTexture = nullptr;

        // initialized to identity
        math::mat4f mPosition;
        
        // initialized to identity
        math::mat4f mRotation;
            
        float mScale = 1;

      SceneAsset(
            FilamentAsset* asset
        ) : mAsset(asset) {
            mAnimator = mAsset->getInstance()->getAnimator();

            mAnimations.resize(2 + mAnimator->getAnimationCount());
            
            for(int i=2; i < mAnimations.size(); i++) {
                mAnimations[i].mDuration = mAnimator->getAnimationDuration(i-2);
            }
        }
    };

}

    