#pragma once

#include <functional>
#include <memory>
#include <chrono>
#include <iostream> 
#include <vector>

#include "ResourceBuffer.hpp"

namespace polyvox { 
    
    using namespace std;

    // 
    // Typedef for a function that loads a resource into a ResourceBuffer from an asset URI.
    //
    using LoadResource = function<ResourceBuffer(const char* uri)>;

    // 
    // Typedef for a function that frees an ID associated with a ResourceBuffer.
    //
    using FreeResource = function<void (uint32_t)>;

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

    // 
    // An animation created by manually passing frame data for morph weights/bone transforms.
    //
    struct RuntimeAnimation {
      
      RuntimeAnimation(float* morphData,
                       int numMorphWeights,
                       float* boneData,
                       const char** boneNames,
                       const char** meshNames,
                       int numBones,
                       int numFrames,
                       float frameLengthInMs) : 
                       mNumFrames(numFrames), 
                       mFrameLengthInMs(frameLengthInMs), 
                       mNumMorphWeights(numMorphWeights), 
                       mNumBones(numBones) {

        if(numMorphWeights > 0) {
          size_t morphSize = numMorphWeights * mNumFrames * sizeof(float);
          mMorphFrameData = (float*)malloc(morphSize);
          memcpy(mMorphFrameData, morphData, morphSize);
        }

        if(numBones > 0) { 
          size_t boneSize = numBones * numFrames * 7 * sizeof(float);
          mBoneFrameData = (float*)malloc(boneSize);
          memcpy(mBoneFrameData, boneData, boneSize);
        }
        
        for(int i =0; i < numBones; i++) {
          mBoneNames.push_back(string(boneNames[i]));
          mMeshNames.push_back(string(meshNames[i]));
        }
      }

      ~RuntimeAnimation() {
        delete(mMorphFrameData);
        delete(mBoneFrameData);
      }
      
      int frameIndex = -1;
      int mNumFrames = -1;
      float mFrameLengthInMs = 0;
      time_point_t startTime;
      
      float* mMorphFrameData = nullptr;
      int mNumMorphWeights = 0;

      float* mBoneFrameData = nullptr;
      int mNumBones = 0;
              
      vector<string> mBoneNames;
      vector<string> mMeshNames;

    };
  
}

