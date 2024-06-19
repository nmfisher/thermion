#ifndef SwiftThermionFlutterPlugin_Bridging_Header_h
#define SwiftThermionFlutterPlugin_Bridging_Header_h

#include <stdint.h>

#include "ResourceBuffer.h"

ResourceLoaderWrapper *make_resource_loader(LoadFilamentResourceFromOwner loadFn, FreeFilamentResourceFromOwner freeFn, void *const owner)
{
    ResourceLoaderWrapper *rlw = (ResourceLoaderWrapper *)malloc(sizeof(ResourceLoaderWrapper));
    rlw->loadResource = NULL;
    rlw->freeResource = NULL;
    rlw->loadToOut = NULL;
    rlw->loadFromOwner = loadFn;
    rlw->freeFromOwner = freeFn;
    rlw->owner = owner;
    return rlw;
}

#endif
