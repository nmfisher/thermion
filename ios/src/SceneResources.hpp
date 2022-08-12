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
    //
    struct BoneAnimationStatus  {        
      BoneAnimationStatus(int animationIndex, float duration, bool loop) : animationIndex(animationIndex), duration(duration), loop(loop) {}
      bool hasStarted = false;
      int animationIndex;
      float duration = 0;
      time_point_t lastTime;
      bool loop;
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