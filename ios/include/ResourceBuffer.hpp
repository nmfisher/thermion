#ifndef RESOURCE_BUFFER_H
#define RESOURCE_BUFFER_H

#include <stdint.h>
#if defined(__cplusplus)
#include "Log.hpp"
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

    typedef struct ResourceBuffer ResourceBuffer;
    typedef ResourceBuffer (*LoadResource)(const char* uri);
    typedef ResourceBuffer (*LoadResourceFromOwner)(const char* const, void* const owner);
    typedef void (*FreeResource)(ResourceBuffer);
    typedef void (*FreeResourceFromOwner)(ResourceBuffer, void* const owner);
    
    struct ResourceLoaderWrapper {
      #if defined(__cplusplus)
        ResourceLoaderWrapper(LoadResource loader, FreeResource freeResource) : mLoadResource(loader), mFreeResource(freeResource) {};
        ResourceLoaderWrapper(LoadResourceFromOwner loader, FreeResourceFromOwner freeResource, void* const owner) : mLoadResourceFromOwner(loader), mFreeResourceFromOwner(freeResource),  mOwner(owner) {};

        ResourceBuffer load(const char* uri) {
          Log("LOADING %s", uri);
          if(mLoadResourceFromOwner) {
            return mLoadResourceFromOwner(uri, mOwner);
          }
          return mLoadResource(uri);
        }

        void free(ResourceBuffer rb) {
          if(mFreeResourceFromOwner) {
            mFreeResourceFromOwner(rb, mOwner);
          } else {
            mFreeResource(rb);
          }
        }
      #endif
        void* mOwner;
        LoadResource mLoadResource;
        FreeResource mFreeResource;
        LoadResourceFromOwner mLoadResourceFromOwner;
        FreeResourceFromOwner mFreeResourceFromOwner;
    };
    typedef struct ResourceLoaderWrapper ResourceLoaderWrapper;
    
    
#if defined(__cplusplus)
}
#endif
#endif
