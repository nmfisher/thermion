#ifndef GRID_H_
#define GRID_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t GRID_PACKAGE[];
    extern int GRID_GRID_OFFSET;
    extern int GRID_GRID_SIZE;
}
#define GRID_GRID_DATA (GRID_PACKAGE + GRID_GRID_OFFSET)

#endif
