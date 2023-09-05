#ifndef STANDARD_H_
#define STANDARD_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t STANDARD_PACKAGE[];
    extern int STANDARD_STANDARD_OFFSET;
    extern int STANDARD_STANDARD_SIZE;
}
#define STANDARD_STANDARD_DATA (STANDARD_PACKAGE + STANDARD_STANDARD_OFFSET)

#endif
