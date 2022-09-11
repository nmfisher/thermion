#pragma once

#include <functional>
#include <memory>

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
      bool play;

      //
      // If [play] is true, this flag will be checked when the animation is complete. If true, the animation will restart.
      //
      bool loop;

      //
      // If true, the animation will be played in reverse.
      //
      bool reverse;
      
      // 
      // If [play] is true, this flag will be set to true when the animation is started.
      // 
      bool started = false;
      
      //
      // The index of the animation in the GLTF asset.
      //
      int animationIndex;
      
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
      
      MorphAnimationStatus(float* frameData,
                           int numWeights,
                           int numFrames,
                           float frameLength) : frameData(frameData), numWeights(numWeights), numFrames(numFrames), frameLengthInMs(frameLength) {
      }
      
      int frameIndex = -1;
      int numFrames;
      float frameLengthInMs;
      time_point_t startTime;
      
      float* frameData;
      int numWeights;
    };
}

