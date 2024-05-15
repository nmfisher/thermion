#ifndef SwiftFlutterFilamentPlugin_Bridging_Header_h
#define SwiftFlutterFilamentPlugin_Bridging_Header_h

#include <stdint.h>

#include "ResourceBuffer.hpp"

ResourceLoaderWrapper *make_resource_loader(LoadFilamentResourceFromOwner loadFn, FreeFilamentResourceFromOwner freeFn, void *const owner)
{
    ResourceLoaderWrapper *rlw = (ResourceLoaderWrapper *)malloc(sizeof(ResourceLoaderWrapper));
    rlw->loadFromOwner = loadFn;
    rlw->freeFromOwner = freeFn;
    rlw->owner = owner;
    return rlw;
}

#endif
