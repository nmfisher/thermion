#pragma once

#include <functional>
#include <memory>
#include <chrono>
#include <iostream> 
#include <vector>

#include "ResourceBuffer.hpp"

namespace polyvox { 
    
    using namespace std;

    // 
    // Typedef for a function that loads a resource into a ResourceBuffer from an asset URI.
    //
    using LoadResource = function<ResourceBuffer(const char* uri)>; 

    // 
    // Typedef for a function that frees an ID associated with a ResourceBuffer.
    //
    using FreeResource = function<void (uint32_t)>;

  
}

