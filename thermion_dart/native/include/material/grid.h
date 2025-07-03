#ifndef GRID_H_
#define GRID_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t GRID_PACKAGE[];
    extern int GRID_GRID_OFFSET;
    extern int GRID_GRID_SIZE;
#ifdef __cplusplus
}
#endif
#define GRID_GRID_DATA (GRID_PACKAGE + GRID_GRID_OFFSET)

#endif
