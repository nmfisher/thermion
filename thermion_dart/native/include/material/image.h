#ifndef IMAGE_H_
#define IMAGE_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t IMAGE_PACKAGE[];
    extern int IMAGE_IMAGE_OFFSET;
    extern int IMAGE_IMAGE_SIZE;
}
#define IMAGE_IMAGE_DATA (IMAGE_PACKAGE + IMAGE_IMAGE_OFFSET)

#endif
