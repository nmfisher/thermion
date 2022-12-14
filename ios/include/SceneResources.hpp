#pragma once

#include <functional>
#include <memory>
#include <chrono>
#include <iostream> 

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
    // Holds the current state of a bone animation embeded in a GLTF asset. 
    // Currently, an instance will be constructed for every animation in an asset whenever a SceneAsset is created (and thus will persist for the lifetime of the SceneAsset).
    //
    struct EmbeddedAnimationStatus  {        
      EmbeddedAnimationStatus(bool loop, bool reverse) : loop(loop), reverse(reverse) {}

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
    // Holds the current state of a morph-target animation in a GLTF asset.
    //
    struct MorphAnimationStatus {
      
      MorphAnimationStatus(float* data,
                           int numWeights,
                           int numFrames,
                           float frameLengthInMs) : numFrames(numFrames), frameLengthInMs(frameLengthInMs), numWeights(numWeights)  {
        size_t size = numWeights * numFrames * sizeof(float);
        frameData = (float*)malloc(size);
        memcpy(frameData, data, size);
      }

      ~MorphAnimationStatus() {
        delete(frameData);
      }
      
      int frameIndex = -1;
      int numFrames = -1;
      float frameLengthInMs = 0;
      time_point_t startTime;
      
      float* frameData = nullptr;
      int numWeights = 0;
    };
}

