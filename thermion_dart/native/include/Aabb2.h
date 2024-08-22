#pragma once

#ifdef __cplusplus
extern "C"
{
#endif
struct Aabb2 {
    float minX;
    float minY;
    float maxX; 
    float maxY;
};

typedef struct Aabb2 Aabb2;

#ifdef __cplusplus
}
#endif