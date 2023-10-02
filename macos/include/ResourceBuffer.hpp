#ifndef RESOURCE_BUFFER_H
#define RESOURCE_BUFFER_H

#include <stdint.h>
#if defined(__cplusplus)
extern "C" {
#endif
    // 
    // Since different platforms expose different interfaces for loading assets, we want single interface to represent the binary data backing an asset (as well as an ID that can be passed back to the native platform to free the data and unload the asset).
    //
    struct ResourceBuffer {
        const void* const data;
        const int32_t size;
        const int32_t id;

        // These only need to be constructible from C++ on Linux & Windows.
        // On iOS, MacOS & Android, this is constructed on the Swift/Kotlin side.
        // These C++ constructors seem to interfere with that, so we omit them on those platforms.
        #if defined(__cplusplus) && !defined(__ANDROID__) && !defined(__APPLE__)
        ResourceBuffer(const void* const data, const int32_t size, const int32_t id) : data(data), size(size), id(id) {};
        ResourceBuffer(const ResourceBuffer& rb) : data(rb.data), size(rb.size), id(rb.id) { };
        ResourceBuffer(const ResourceBuffer&& rb) : data(rb.data), size(rb.size), id(rb.id) { };
        ResourceBuffer& operator=(const ResourceBuffer& other) = delete;
        #endif
    };

    typedef struct ResourceBuffer ResourceBuffer;
    typedef ResourceBuffer (*LoadFilamentResource)(const char* uri);
    typedef ResourceBuffer (*LoadFilamentResourceFromOwner)(const char* const, void* const owner);
    typedef void (*FreeFilamentResource)(ResourceBuffer);
    typedef void (*FreeFilamentResourceFromOwner)(ResourceBuffer, void* const owner);
    
    // this may be compiled as either C or C++, depending on which compiler is being invoked (e.g. binding to Swift will compile as C).
    // the former does not allow default initialization to be specified inline), so we need to explicitly set the unused members to nullptr
    struct ResourceLoaderWrapper {
      #if defined(__cplusplus)
        ResourceLoaderWrapper(LoadFilamentResource loader, FreeFilamentResource freeResource) : mLoadFilamentResource(loader), mFreeFilamentResource(freeResource), mLoadFilamentResourceFromOwner(nullptr), mFreeFilamentResourceFromOwner(nullptr),
        mOwner(nullptr) {}
        
        ResourceLoaderWrapper(LoadFilamentResourceFromOwner loader, FreeFilamentResourceFromOwner freeResource, void* const owner) : mLoadFilamentResource(nullptr), mFreeFilamentResource(nullptr), mLoadFilamentResourceFromOwner(loader), mFreeFilamentResourceFromOwner(freeResource), mOwner(owner) {
            
        };

        ResourceBuffer load(const char* uri) const {
          if(mLoadFilamentResourceFromOwner) {
            auto rb = mLoadFilamentResourceFromOwner(uri, mOwner);
            return rb;
          }
          auto rb =mLoadFilamentResource(uri);
          return rb;
        }

        void free(ResourceBuffer rb) const {
          if(mFreeFilamentResourceFromOwner) {
            mFreeFilamentResourceFromOwner(rb, mOwner);
          } else {
            mFreeFilamentResource(rb);
          }
        }
      #endif
        LoadFilamentResource mLoadFilamentResource;
        FreeFilamentResource mFreeFilamentResource;
        LoadFilamentResourceFromOwner mLoadFilamentResourceFromOwner;
        FreeFilamentResourceFromOwner mFreeFilamentResourceFromOwner;
        void* mOwner;
    };
    typedef struct ResourceLoaderWrapper ResourceLoaderWrapper;
    
    
#if defined(__cplusplus)
}
#endif
#endif
