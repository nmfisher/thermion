#ifndef RESOURCE_BUFFER_H
#define RESOURCE_BUFFER_H

#include <stdint.h>
#include <stdlib.h>

//
// A ResourceBuffer is a unified interface for working with
// binary assets across various platforms.
// This is simply:
// 1) a pointer to some data
// 2) the length of the data
// 3) an ID that can be passed back to the native platform to release the underlying asset when needed.
//
struct ResourceBuffer
{
  const void *const data;
  const int32_t size;
  const int32_t id;
};

typedef struct ResourceBuffer ResourceBuffer;
typedef ResourceBuffer (*LoadFilamentResource)(const char *uri);
typedef ResourceBuffer (*LoadFilamentResourceFromOwner)(const char *const, void *const owner);
typedef void (*FreeFilamentResource)(ResourceBuffer);
typedef void (*FreeFilamentResourceFromOwner)(ResourceBuffer, void *const owner);

struct ResourceLoaderWrapper
{
  LoadFilamentResource loadResource;
  FreeFilamentResource freeResource;
  LoadFilamentResourceFromOwner loadFromOwner;
  FreeFilamentResourceFromOwner freeFromOwner;
  void *owner;
};
typedef struct ResourceLoaderWrapper ResourceLoaderWrapper;


#if defined(__cplusplus)

namespace flutter_filament {

// struct ResourceBufferImpl : public ResourceBuffer
// {

//   ResourceBufferImpl(const void *const mData, const int32_t mSize, const int32_t mId)
//   {
//     data = mData;
//     size = mSize;
//     id = mId;
//   };

//   ResourceBufferImpl(const ResourceBufferImpl &rb)
//   {
//     (void *)data = rb.data;
//     size = rb.size;
//     id = rb.id;
//   };

//   ResourceBufferImpl(const ResourceBufferImpl &&rb) noexcept
//   {
//     data = rb.data;
//     size = rb.size;
//     id = rb.id;
//   };
//   ResourceBufferImpl &operator=(const ResourceBufferImpl &other) = delete;
// };

struct ResourceLoaderWrapperImpl : public ResourceLoaderWrapper
{

  ResourceLoaderWrapperImpl(LoadFilamentResource loader, FreeFilamentResource freeResource)
  {
    loadFromOwner = nullptr;
    freeFromOwner = nullptr;
    loadResource = loader;
    freeResource = freeResource;
    owner = nullptr;
  }

  ResourceLoaderWrapperImpl(LoadFilamentResourceFromOwner loader, FreeFilamentResourceFromOwner freeResource, void * owner)
  {
    loadResource = nullptr;
    freeResource = nullptr;
    loadFromOwner = loader;
    freeFromOwner = freeResource;
    owner = owner;
  }

  ResourceBuffer load(const char *uri) const
  {
    if (loadFromOwner)
    {
      auto rb = loadFromOwner(uri, owner);
      return rb;
    }
    auto rb = loadResource(uri);
    return rb;
  }

  void free(ResourceBuffer rb) const
  {
    if (freeFromOwner)
    {
      freeFromOwner(rb, owner);
    }
    else
    {
      freeResource(rb);
    }
  }
};

}
#endif

#endif
