#ifndef RESOURCE_BUFFER_HPP
#define RESOURCE_BUFFER_HPP

#include "ResourceBuffer.h"

#ifndef __EMSCRIPTEN__
#include <thread>
using namespace std::chrono_literals;
#endif

namespace thermion
{

  struct ResourceLoaderWrapperImpl : public ResourceLoaderWrapper
  {

    ResourceLoaderWrapperImpl(ResourceLoaderWrapper* wrapper) {
      loadFromOwner = wrapper->loadFromOwner;
      freeFromOwner = wrapper->freeFromOwner;
      loadResource = wrapper->loadResource;
      freeResource = wrapper->freeResource;
      owner = wrapper->owner;
      loadToOut = wrapper->loadToOut;
    }

    ResourceLoaderWrapperImpl(LoadFilamentResource loader, FreeFilamentResource freeResource)
    {
      loadFromOwner = nullptr;
      freeFromOwner = nullptr;
      loadResource = loader;
      freeResource = freeResource;
      owner = nullptr;
    }

    ResourceLoaderWrapperImpl(LoadFilamentResourceFromOwner loader, FreeFilamentResourceFromOwner freeResource, void *owner)
    {
      loadResource = nullptr;
      freeResource = nullptr;
      loadFromOwner = loader;
      freeFromOwner = freeResource;
      owner = owner;
    }

    ResourceBuffer load(const char *uri) const
    {
      if (loadToOut)
      {
        ResourceBuffer rb(nullptr, 0, -1);
        loadToOut(uri, &rb);
        while (rb.size == 0)
        {
          #if! __EMSCRIPTEN__
          std::this_thread::sleep_for(100ms);
          #endif
        }

        return rb;
      }
      else if (loadFromOwner)
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

