#ifndef OUTLINE_H_
#define OUTLINE_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t OUTLINE_PACKAGE[];
    extern int OUTLINE_OUTLINE_OFFSET;
    extern int OUTLINE_OUTLINE_SIZE;
}
#define OUTLINE_OUTLINE_DATA (OUTLINE_PACKAGE + OUTLINE_OUTLINE_OFFSET)

#endif
