#ifndef CAPTURE_UV_H_
#define CAPTURE_UV_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t CAPTURE_UV_PACKAGE[];
    extern int CAPTURE_UV_CAPTURE_UV_OFFSET;
    extern int CAPTURE_UV_CAPTURE_UV_SIZE;
}
#define CAPTURE_UV_CAPTURE_UV_DATA (CAPTURE_UV_PACKAGE + CAPTURE_UV_CAPTURE_UV_OFFSET)

#endif
