#ifndef SCENE_ASSET_ANIMATION_H_
#define SCENE_ASSET_ANIMATION_H_

#include "utils/Entity.h"
#include <filament/RenderableManager.h>

namespace polyvox {
    
    using namespace std;
    
    using Instance = utils::EntityInstance<filament::RenderableManager>;

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;   

    // 
    // Holds the current state of a GLTF animation. 
    // Whenever a SceneAsset is created, an instance of GLTFAnimation will be created for every embedded animation.
    // On each frame loop, we check if [play] is true, and if so, advance the animation to the correct frame based on [startedAt].
    // The [GLTFAnimation] will persist for the lifetime of the SceneAsset.
    //
    struct GLTFAnimation  {        
      GLTFAnimation(bool loop, bool reverse) : loop(loop), reverse(reverse) {}

      // 
      // A flag that is checked each frame to determine whether or not the animation should play.
      //
      bool play = false;

      //
      // If [play] is true, this flag will be checked when the animation is complete. If true, the animation will restart.
      //
      bool loop = false;

      //
      // If true, the animation will be played in reverse.
      //
      bool reverse = false;
      
      // 
      // If [play] is true, this flag will be set to true when the animation is started.
      // 
      bool started = false;
      
      //
      // The index of the animation in the GLTF asset.
      //
      int animationIndex = -1;
      
      //
      // The time point at which this animation was last started.
      // This is used to calculate the "animation time offset" that is passed to the Animator.
      //
      time_point_t startedAt;

    };

    ///
    /// Holds a single set of frame data that may be used to animate multiple bones/meshes.
    ///
    struct BoneTransformTarget {

        size_t skinIndex = 0;
        unique_ptr<vector<uint8_t>> mBoneIndices;
        unique_ptr<vector<utils::Entity>> mMeshTargets;
        unique_ptr<vector<float>> mBoneData;

        BoneTransformTarget(
          unique_ptr<vector<uint8_t>>& boneIndices,
          unique_ptr<vector<utils::Entity>>& meshTargets,
          unique_ptr<vector<float>>& boneData) : mBoneIndices(move(boneIndices)), mMeshTargets(move(meshTargets)), mBoneData(move(boneData)) {}

    };

    // 
    // An animation created by manually passing frame data for morph weights/bone transforms.
    //
    struct RuntimeAnimation {

      Instance mInstance;

      int frameNumber = -1;
      int mNumFrames = -1;
      float mFrameLengthInMs = 0;
      time_point_t startTime;

      
      float* mMorphFrameData = nullptr;
      int mNumMorphWeights = 0;

      unique_ptr<vector<BoneTransformTarget>> mTargets;
      
      RuntimeAnimation(Instance instance,
                       const float* const morphData,
                       int numMorphWeights,
                       unique_ptr<vector<BoneTransformTarget>>& targets,
                       int numFrames,
                       float frameLengthInMs) : 
                       mInstance(instance),
                       mNumFrames(numFrames), 
                       mFrameLengthInMs(frameLengthInMs), 
                       mNumMorphWeights(numMorphWeights),
                      mTargets(move(targets)) {

        if(numMorphWeights > 0) {
          size_t morphSize = numMorphWeights * mNumFrames * sizeof(float);
          mMorphFrameData = (float*)malloc(morphSize);
          memcpy(mMorphFrameData, morphData, morphSize);
        }
      }

      ~RuntimeAnimation() {
        delete(mMorphFrameData);
      }
    };
    
}

#endif
