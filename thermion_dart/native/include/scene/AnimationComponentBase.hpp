#pragma once

#include <cstdint>

namespace thermion
{
    struct AnimationComponentBase
    {
        // The frame time (in nanoseconds) when this animation started playing.
        uint64_t startTimeInNanos = 0;

        // Whether the animation should be played from its first frame, or at some later time.
        float startOffset;

        // Whether the animation should loop back to the start when it finishes.
        bool loop = false;

        // Whether the animation should be played backwards or forwards.
        bool reverse = false;

        // The duration of the animation in seconds.
        float durationInSecs = 0;

        // The speed at which this animation should be played.
        float speed = 1.0f;
    };
}
