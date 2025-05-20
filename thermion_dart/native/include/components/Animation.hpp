#pragma once

#include <chrono>

namespace thermion
{
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