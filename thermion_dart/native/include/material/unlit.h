#ifndef UNLIT_H_
#define UNLIT_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t UNLIT_PACKAGE[];
    extern int UNLIT_UNLIT_OFFSET;
    extern int UNLIT_UNLIT_SIZE;
}
#define UNLIT_UNLIT_DATA (UNLIT_PACKAGE + UNLIT_UNLIT_OFFSET)

#endif
