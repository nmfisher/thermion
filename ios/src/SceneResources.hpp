#pragma once

#include <functional>

namespace polyvox { 

      // 
      // Pairs a memory buffer with an ID that can be used to unload the backing asset if needed.
      // Use this when you want to load an asset from a resource that requires more than just `free` on the underlying buffer.
      // e.g. 
      // ```
      // uint64_t id = get_next_resource_id();
      // AAsset *asset = AAssetManager_open(am, name, AASSET_MODE_BUFFER);
      // off_t length = AAsset_getLength(asset);
      // const void * buffer = AAsset_getBuffer(asset);
      // uint8_t *buf = new uint8_t[length ];
      // memcpy(buf,buffer,  length);
      // ResourceBuffer rb(buf, length, id);
      // ...
      // ...
      // (elsewhere)
      // AAsset* asset = get_asset_from_id(rb.id);
      // AAsset_close(asset);
      // free_asset_id(rb.id);
      //
      struct ResourceBuffer {
        ResourceBuffer(const void* data, const uint32_t size, const uint32_t id) : data(data), size(size), id(id) {};

        ResourceBuffer& operator=(ResourceBuffer other)
        {
          data = other.data;
          size = other.size;
          id = other.id;
          return *this;
        }
        const void* data;
        uint32_t size;
        uint32_t id;
    };
    
    // 
    // Typedef for any function that loads a resource into a ResourceBuffer from an asset URI.
    //
    using LoadResource = std::function<ResourceBuffer(const char* uri)>;

    // 
    // Typedef for any function that frees a ResourceBuffer.
    //
    using FreeResource = std::function<void (ResourceBuffer)>;

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;   

    // 
    // Holds the current state of a bone animation embeded in a GLTF asset. 
    // Currently, an instance will be constructed for every animation in an asset whenever a SceneAsset is created (and thus will persist for the lifetime of the SceneAsset).
    //
    struct EmbeddedAnimationStatus  {        
      EmbeddedAnimationStatus(int animationIndex, float duration, bool loop) : animationIndex(animationIndex), duration(duration), loop(loop) {}

      // 
      // A flag that is checked each frame to determine whether or not the animation should play.
      //
      bool play;

      //
      // If [play] is true, this flag will be checked when the animation is complete. If true, the animation will restart.
      //
      bool loop;
      
      // 
      // If [play] is true, this flag will be set to true when the animation is started.
      // 
      bool started = false;
      
      //
      // The index of the animation in the GLTF asset.
      //
      int animationIndex;
      
      //
      // The duration of the animation (calculated from the GLTF animator). 
      //
      float duration = 0;

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