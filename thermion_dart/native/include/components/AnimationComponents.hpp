#pragma once

#include <chrono>
#include <vector>

#include <gltfio/FilamentInstance.h>

#include <math/vec3.h>
#include <math/vec4.h>
#include <math/mat3.h>
#include <math/norm.h>

#include "Log.hpp"

namespace thermion
{
    using namespace filament;
    using namespace std::chrono;

    typedef std::chrono::time_point<std::chrono::high_resolution_clock> time_point_t;

    struct Animation
    {
        time_point_t start = time_point_t::max();
        float startOffset;
        bool loop = false;
        bool reverse = false;
        float durationInSecs = 0;
    };


   


}
