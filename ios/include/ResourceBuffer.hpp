#ifndef RESOURCE_BUFFER_H
#define RESOURCE_BUFFER_H

#include <stdint.h>
#if defined(__cplusplus)
extern "C" {
#endif
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
        #if defined(__cplusplus)
        ResourceBuffer(const void* data, const uint32_t size, const uint32_t id) : data(data), size(size), id(id) {};
        ResourceBuffer& operator=(ResourceBuffer other) {
          data = other.data;
          size = other.size;
          id = other.id;
          return *this;
        }
        #endif
        const void* data;
        uint32_t size;
        uint32_t id;
    };
#if defined(__cplusplus)
}
#endif
#endif
