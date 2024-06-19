#include "ResourceBuffer.h"

void *make_resource_loader(LoadFilamentResourceFromOwner loadFn, FreeFilamentResourceFromOwner freeFn, void *const owner)
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
