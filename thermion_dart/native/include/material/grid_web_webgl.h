#ifndef GRID_WEB_WEBGL_H_
#define GRID_WEB_WEBGL_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t GRID_PACKAGE[];
#ifdef __cplusplus
}
#endif

#define GRID_GRID_OFFSET 0
#define GRID_GRID_SIZE 14801
#define GRID_GRID_DATA (GRID_PACKAGE + GRID_GRID_OFFSET)

#endif
