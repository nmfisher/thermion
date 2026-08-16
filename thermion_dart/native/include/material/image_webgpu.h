#ifndef IMAGE_WEBGPU_H_
#define IMAGE_WEBGPU_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    extern const uint8_t IMAGE_PACKAGE[];
#ifdef __cplusplus
}
#endif

#define IMAGE_IMAGE_OFFSET 0
#define IMAGE_IMAGE_SIZE 19626
#define IMAGE_IMAGE_DATA (IMAGE_PACKAGE + IMAGE_IMAGE_OFFSET)

#endif
