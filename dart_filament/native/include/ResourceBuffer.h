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

#if defined(__cplusplus)
  ResourceBuffer(void *const data, int32_t size, int32_t id) : data(data), size(size), id(id) {}
#endif
};

typedef struct ResourceBuffer ResourceBuffer;
typedef void (*LoadFilamentResourceIntoOutPointer)(const char *uri, ResourceBuffer *out);
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
  LoadFilamentResourceIntoOutPointer loadToOut;
};
typedef struct ResourceLoaderWrapper ResourceLoaderWrapper;

ResourceLoaderWrapper *make_resource_loader(LoadFilamentResourceFromOwner loadFn, FreeFilamentResourceFromOwner freeFn, void *const owner);

#endif
